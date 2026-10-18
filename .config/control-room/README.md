# control-room

Holds the private key for the `control-room-review` GitHub App (App ID
`4944334`), installed on all `superhighfives` repos so
[superhighfives/control-room](https://github.com/superhighfives/control-room)'s
review workflow can actually submit `APPROVE` reviews — see that repo's
README ("Making blocking actually block") for the full setup.

`app-private-key.pem` is **not** tracked here (see this repo's `.gitignore` —
a leaked App key can approve pull requests on every repo it's installed on).
Restore it from 1Password to:

    ~/.config/control-room/app-private-key.pem

`control-room/scripts/add-repo.sh` reads it from this path by default
(override with `CONTROL_ROOM_APP_KEY`).
