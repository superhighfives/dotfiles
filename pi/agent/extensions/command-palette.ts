/**
 * Command palette (Ctrl+P)
 *
 * An opencode-style fuzzy command palette. Opens as a centered overlay; type
 * to filter, ↑↓ to move, Enter to run, Esc to close.
 *
 * Contents:
 * - Every invocable slash command from `pi.getCommands()` (extension commands,
 *   prompt templates, skills). Extension commands run immediately; prompt/skill
 *   commands (which usually take arguments) are prefilled into the editor.
 * - Curated built-in actions that have programmatic equivalents and can run
 *   straight from a shortcut context: model select, thinking level, compact,
 *   toggle tool output, switch theme.
 * - Built-in interactive commands that have no programmatic entrypoint
 *   (/new, /resume, /fork, /tree, /settings, /reload) are prefilled into the
 *   editor so you just press Enter to confirm.
 *
 * Ctrl+P is pi's default `app.model.cycleForward`. This extension claims it;
 * keybindings.json rebinds model-cycling to Alt+P / Alt+Shift+P.
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { type TUI, Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
const THINKING_LEVELS: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

interface PaletteItem {
	id: string;
	label: string;
	category: string;
	description?: string;
	/** Right-aligned hint, e.g. "↵ prefill". */
	hint?: string;
	run: (ctx: ExtensionContext) => Promise<void> | void;
}

function sendSlash(pi: ExtensionAPI, ctx: ExtensionContext, command: string): void {
	if (ctx.isIdle()) {
		pi.sendUserMessage(command);
	} else {
		pi.sendUserMessage(command, { deliverAs: "followUp" });
		ctx.ui.notify(`Queued ${command} as a follow-up`, "info");
	}
}

function buildBuiltinActions(pi: ExtensionAPI): PaletteItem[] {
	// Directly runnable from a shortcut/ExtensionContext.
	const direct: PaletteItem[] = [
		{
			id: "builtin:model",
			label: "Select model",
			category: "model",
			description: "Switch the active model",
			run: async (ctx) => {
				const models = ctx.modelRegistry.getAvailable();
				const labels = models.map((m) => `${m.provider}/${m.id}`);
				const choice = await ctx.ui.select("Select model", labels);
				if (!choice) return;
				const model = models.find((m) => `${m.provider}/${m.id}` === choice);
				if (!model) return;
				const ok = await pi.setModel(model);
				if (!ok) ctx.ui.notify(`No API key for ${choice}`, "error");
			},
		},
		{
			id: "builtin:thinking",
			label: "Set thinking level",
			category: "model",
			description: `Currently: ${pi.getThinkingLevel()}`,
			run: async (ctx) => {
				const choice = await ctx.ui.select("Thinking level", [...THINKING_LEVELS]);
				if (choice) pi.setThinkingLevel(choice as ThinkingLevel);
			},
		},
		{
			id: "builtin:compact",
			label: "Compact conversation",
			category: "session",
			description: "Summarize and shrink the context now",
			run: (ctx) => ctx.compact(),
		},
		{
			id: "builtin:tools-expand",
			label: "Toggle tool output",
			category: "view",
			description: "Expand or collapse tool call output",
			run: (ctx) => ctx.ui.setToolsExpanded(!ctx.ui.getToolsExpanded()),
		},
		{
			id: "builtin:theme",
			label: "Switch theme",
			category: "view",
			description: "Change the color theme",
			run: async (ctx) => {
				const themes = ctx.ui.getAllThemes();
				const choice = await ctx.ui.select("Theme", themes.map((t) => t.name));
				if (!choice) return;
				const result = ctx.ui.setTheme(choice);
				if (!result.success) ctx.ui.notify(`Failed to set theme: ${result.error}`, "error");
			},
		},
	];

	// Built-in interactive commands with no programmatic entrypoint: prefill the
	// editor and let the user confirm with Enter.
	const prefill: Array<{ label: string; command: string; description: string }> = [
		{ label: "New session", command: "/new", description: "Start a fresh session" },
		{ label: "Resume session", command: "/resume", description: "Open the session picker" },
		{ label: "Fork session", command: "/fork", description: "Branch from an earlier point" },
		{ label: "Session tree", command: "/tree", description: "Navigate the session tree" },
		{ label: "Settings", command: "/settings", description: "Open settings" },
		{ label: "Reload", command: "/reload", description: "Reload extensions, skills, themes" },
	];
	const prefillItems: PaletteItem[] = prefill.map((entry) => ({
		id: `builtin:prefill:${entry.command}`,
		label: entry.label,
		category: "session",
		description: entry.description,
		hint: "↵ prefill",
		run: (ctx) => ctx.ui.setEditorText(`${entry.command} `),
	}));

	return [...direct, ...prefillItems];
}

function buildCommandItems(pi: ExtensionAPI): PaletteItem[] {
	return pi.getCommands().map((command) => {
		const name = command.name;
		const runsImmediately = command.source === "extension";
		return {
			id: `cmd:${name}`,
			label: `/${name}`,
			category: command.source,
			description: command.description,
			hint: runsImmediately ? undefined : "↵ prefill",
			run: (ctx) => {
				if (runsImmediately) {
					sendSlash(pi, ctx, `/${name}`);
				} else {
					// Prompt templates and skills usually take arguments.
					ctx.ui.setEditorText(`/${name} `);
				}
			},
		};
	});
}

function buildItems(pi: ExtensionAPI): PaletteItem[] {
	return [...buildBuiltinActions(pi), ...buildCommandItems(pi)];
}

/** Subsequence fuzzy match. Returns a score (lower is better) or null. */
function fuzzyScore(query: string, text: string): number | null {
	if (!query) return 0;
	const q = query.toLowerCase();
	const t = text.toLowerCase();
	let ti = 0;
	let score = 0;
	let lastMatch = -1;
	for (const char of q) {
		const found = t.indexOf(char, ti);
		if (found === -1) return null;
		// Penalize gaps between matched characters (favors tight, contiguous hits).
		if (lastMatch !== -1) score += found - lastMatch - 1;
		lastMatch = found;
		ti = found + 1;
	}
	// Prefer earlier first matches and shorter haystacks.
	return score + lastMatch * 0.5 + t.length * 0.01;
}

class PaletteOverlay {
	private search = "";
	private selectedIndex = 0;
	private cachedWidth?: number;
	private cachedLines?: string[];

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly items: PaletteItem[],
		private readonly done: (result: PaletteItem | null) => void,
	) {}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl("c"))) {
			this.done(null);
			return;
		}
		if (matchesKey(data, Key.enter)) {
			const item = this.filtered()[this.selectedIndex];
			this.done(item ?? null);
			return;
		}
		if (matchesKey(data, Key.up)) {
			this.move(-1);
			return;
		}
		if (matchesKey(data, Key.down)) {
			this.move(1);
			return;
		}
		if (matchesKey(data, Key.backspace)) {
			if (this.search.length > 0) {
				this.search = Array.from(this.search).slice(0, -1).join("");
				this.selectedIndex = 0;
				this.rerender();
			}
			return;
		}
		if (isPrintable(data)) {
			this.search += data;
			this.selectedIndex = 0;
			this.rerender();
		}
	}

	private rerender(): void {
		this.invalidate();
		this.tui.requestRender();
	}

	private move(delta: number): void {
		const count = this.filtered().length;
		if (count === 0) return;
		this.selectedIndex = Math.max(0, Math.min(this.selectedIndex + delta, count - 1));
		this.invalidate();
		this.tui.requestRender();
	}

	private filtered(): PaletteItem[] {
		const query = this.search.trim();
		if (!query) return this.items;
		return this.items
			.map((item) => ({
				item,
				score: fuzzyScore(query, `${item.label} ${item.category} ${item.description ?? ""}`),
			}))
			.filter((entry): entry is { item: PaletteItem; score: number } => entry.score !== null)
			.sort((a, b) => a.score - b.score)
			.map((entry) => entry.item);
	}

	render(width: number): string[] {
		if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;

		const innerWidth = Math.max(20, width - 2);
		const border = (text: string): string => this.theme.fg("border", text);
		const line = (content: string) => {
			const truncated = truncateToWidth(content, innerWidth, "…");
			const pad = Math.max(0, innerWidth - visibleWidth(truncated));
			return border("│") + truncated + " ".repeat(pad) + border("│");
		};

		const filtered = this.filtered();
		if (filtered.length > 0) this.selectedIndex = Math.min(this.selectedIndex, filtered.length - 1);

		const maxRows = Math.max(4, Math.min(14, (this.tui.terminal.rows ?? 30) - 10));
		const start = Math.max(
			0,
			Math.min(this.selectedIndex - Math.floor(maxRows / 2), Math.max(0, filtered.length - maxRows)),
		);
		const end = Math.min(filtered.length, start + maxRows);

		const lines: string[] = [];
		lines.push(border(`╭${"─".repeat(innerWidth)}╮`));
		lines.push(line(` ${this.theme.fg("accent", this.theme.bold("Command Palette"))} ${this.theme.fg("dim", `(${filtered.length})`)}`));
		lines.push(line(` ${this.theme.fg("muted", `› ${this.search || "type to filter…"}`)}`));
		lines.push(border(`├${"─".repeat(innerWidth)}┤`));

		if (filtered.length === 0) {
			lines.push(line(` ${this.theme.fg("dim", "No matching commands")}`));
		}
		for (let i = start; i < end; i += 1) {
			const item = filtered[i]!;
			const selected = i === this.selectedIndex;
			const marker = selected ? "›" : " ";
			const hint = item.hint ? this.theme.fg("dim", ` ${item.hint}`) : "";
			const category = this.theme.fg("dim", ` [${item.category}]`);
			const labelText = `${marker} ${item.label}`;
			const head = selected
				? this.theme.fg("accent", this.theme.bold(labelText))
				: labelText;
			lines.push(line(` ${head}${category}${hint}`));
			if (item.description) {
				lines.push(line(`   ${this.theme.fg("dim", item.description)}`));
			}
		}

		lines.push(border(`├${"─".repeat(innerWidth)}┤`));
		lines.push(line(this.theme.fg("dim", " ↑↓ move · ↵ run · esc close")));
		lines.push(border(`╰${"─".repeat(innerWidth)}╯`));

		this.cachedWidth = width;
		this.cachedLines = lines;
		return lines;
	}

	invalidate(): void {
		this.cachedWidth = undefined;
		this.cachedLines = undefined;
	}
}

function isPrintable(data: string): boolean {
	return data.length > 0 && !data.includes("\x1b") && !data.includes("\r") && !data.includes("\n") && data >= " ";
}

export default function (pi: ExtensionAPI) {
	const open = async (ctx: ExtensionContext): Promise<void> => {
		if (ctx.mode !== "tui" || !ctx.hasUI) {
			ctx.ui.notify("Command palette requires interactive mode", "warning");
			return;
		}
		const items = buildItems(pi);
		const selected = await ctx.ui.custom<PaletteItem | null>(
			(tui, theme, _kb, done) => new PaletteOverlay(tui, theme, items, done),
			{ overlay: true, overlayOptions: { anchor: "center", width: "70%", minWidth: 60, maxHeight: "80%" } },
		);
		if (selected) await selected.run(ctx);
	};

	pi.registerShortcut("ctrl+p", { description: "Open command palette", handler: open });
	pi.registerCommand("palette", {
		description: "Open the command palette",
		handler: async (_args, ctx) => open(ctx),
	});
}
