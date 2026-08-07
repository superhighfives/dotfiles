/**
 * btw — out-of-band "by the way" questions
 *
 * `/btw <question>` asks a quick side question that does NOT touch the main
 * task. The current conversation branch is passed as READ-ONLY context so the
 * answer can be about the ongoing work ("wait, why did you pick X?"), but the
 * Q&A is never written back into the LLM context — the main agent never sees
 * it. The answer renders inline as a dim, clearly-marked out-of-context card.
 *
 * Mechanics:
 * - A separate `complete()` call to a fast/cheap model (not your main model).
 * - Its own AbortController (the loader's signal) so Esc-ing the main turn
 *   does not cancel the side question, and vice-versa.
 * - `pi.appendEntry()` + `pi.registerEntryRenderer()` — custom entries are
 *   displayed in the transcript but excluded from LLM context by design.
 */

import { complete } from "@earendil-works/pi-ai/compat";
import type { Api, Model, UserMessage } from "@earendil-works/pi-ai";
import {
	BorderedLoader,
	getMarkdownTheme,
	type ExtensionAPI,
	type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Text } from "@earendil-works/pi-tui";

const ENTRY_TYPE = "btw";

const SYSTEM_PROMPT = `You are a side assistant answering an out-of-band "by the way" question.

You are given the recent conversation between the user and their main coding assistant as READ-ONLY context. The user has stepped aside to ask you something.

Rules:
- Answer the user's question directly and concisely.
- Your answer is shown ONLY to the user. It is NOT sent to the main assistant and does NOT change the ongoing task. Never address the main assistant or issue instructions to it.
- Ground your answer in the provided conversation when relevant, but you may use general knowledge.
- Prefer a short answer. Use markdown. Do not restate the question.`;

interface FastModelPreference {
	provider: string;
	modelId: string;
}

// Fast, cheap models preferred for side questions — never the main (opus) model
// unless nothing else is authed.
const FAST_MODEL_PREFERENCES: readonly FastModelPreference[] = [
	{ provider: "anthropic", modelId: "claude-haiku-4-5" },
	{ provider: "openai-codex", modelId: "gpt-5.5" },
	{ provider: "openai", modelId: "gpt-5-mini" },
];

interface BtwData {
	question: string;
	answer: string;
	model: string;
}

type Outcome =
	| { type: "success"; answer: string }
	| { type: "cancelled" }
	| { type: "error"; message: string };

function getTextParts(content: string | Array<{ type: string; text?: string }>): string {
	if (typeof content === "string") return content.trim();
	return content
		.filter((part): part is { type: "text"; text: string } => part.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n")
		.trim();
}

/** Serialize the recent conversation branch into a compact read-only transcript. */
function buildTranscript(ctx: ExtensionContext, maxChars = 12000): string {
	const parts: string[] = [];
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message") continue;
		const message = entry.message;
		if (!("role" in message)) continue;
		if (message.role === "user") {
			const text = getTextParts(message.content);
			if (text) parts.push(`User: ${text}`);
		} else if (message.role === "assistant") {
			const text = getTextParts(message.content);
			if (text) parts.push(`Assistant: ${text}`);
		}
	}
	const transcript = parts.join("\n\n");
	// Keep the most recent context if it runs long.
	return transcript.length > maxChars ? `…\n${transcript.slice(-maxChars)}` : transcript;
}

async function selectFastModel(ctx: ExtensionContext): Promise<Model<Api> | undefined> {
	for (const candidate of FAST_MODEL_PREFERENCES) {
		const model = ctx.modelRegistry.find(candidate.provider, candidate.modelId);
		if (!model) continue;
		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
		if (auth.ok) return model;
	}
	// Fall back to the current model rather than failing outright.
	if (ctx.model) {
		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
		if (auth.ok) return ctx.model;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.registerEntryRenderer<BtwData>(ENTRY_TYPE, (entry, _options, theme) => {
		const data = entry.data;
		if (!data) return undefined;

		const box = new Box(1, 0, (s: string) => theme.bg("customMessageBg", s));
		box.addChild(
			new Text(
				`${theme.fg("customMessageLabel", theme.bold("btw"))} ${theme.fg("dim", `· out of context · ${data.model}`)}`,
				0,
				0,
			),
		);
		box.addChild(new Text(theme.fg("customMessageText", `Q: ${data.question}`), 0, 0));
		box.addChild(new Markdown(data.answer, 0, 0, getMarkdownTheme()));
		return box;
	});

	pi.registerCommand(ENTRY_TYPE, {
		description: "Ask a side question answered out-of-band (not added to the task context)",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) {
				ctx.ui.notify("btw requires interactive mode", "error");
				return;
			}

			const question = args.trim();
			if (!question) {
				ctx.ui.notify("Usage: /btw <question>", "warning");
				return;
			}

			const model = await selectFastModel(ctx);
			if (!model) {
				ctx.ui.notify("No model with a configured API key is available for btw", "error");
				return;
			}

			const transcript = buildTranscript(ctx);
			const userMessage: UserMessage = {
				role: "user",
				content: [
					{
						type: "text",
						text: transcript
							? `<conversation_context>\n${transcript}\n</conversation_context>\n\nQuestion: ${question}`
							: `Question: ${question}`,
					},
				],
				timestamp: Date.now(),
			};

			const outcome = await ctx.ui.custom<Outcome>((tui, theme, _kb, done) => {
				const loader = new BorderedLoader(tui, theme, `btw → ${model.provider}/${model.id}…`);
				loader.onAbort = () => done({ type: "cancelled" });

				(async (): Promise<Outcome> => {
					const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
					if (!auth.ok) {
						return { type: "error", message: `No auth for ${model.provider}/${model.id}: ${auth.error}` };
					}
					const response = await complete(
						model,
						{ systemPrompt: SYSTEM_PROMPT, messages: [userMessage] },
						{
							apiKey: auth.apiKey,
							headers: auth.headers,
							signal: loader.signal,
							...(model.provider === "openai-codex" ? { reasoningEffort: "none" as const } : {}),
						},
					);
					if (response.stopReason === "aborted") return { type: "cancelled" };
					const answer = getTextParts(response.content);
					return { type: "success", answer: answer || "(no answer)" };
				})()
					.then(done)
					.catch((error) => done({ type: "error", message: error instanceof Error ? error.message : String(error) }));

				return loader;
			});

			if (outcome.type === "cancelled") {
				ctx.ui.notify("btw cancelled", "info");
				return;
			}
			if (outcome.type === "error") {
				ctx.ui.notify(outcome.message, "error");
				return;
			}

			pi.appendEntry<BtwData>(ENTRY_TYPE, {
				question,
				answer: outcome.answer,
				model: `${model.provider}/${model.id}`,
			});
		},
	});
}
