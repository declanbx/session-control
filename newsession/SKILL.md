---
name: newsession
description: Use when the user types /newsession, or asks Claude to open, start or hand work off to a new Claude Code session (e.g. "hand this off to a new session", "open a new session in my thesis folder"), to open it in a new Terminal window, optionally with a first prompt.
argument-hint: <repo> [account] [— first prompt]
---
Open a new Terminal window running Claude at a repo root with the launcher script, then stop. Never write the
`osascript` / `cd` command yourself: the script is the only way this skill opens a session.

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/newsession/open.sh" <repo> [<account>] [<prompt-file>]
```

- `<repo>`: a repo key or alias from `sessions.conf` beside the script; `open.sh --list` prints them. The script
  moves any path inside a listed repo up to that repo's root, so a session never opens in a subfolder: a handoff
  that lives in a subfolder goes in the first prompt as a path (`Read docs/HANDOFF.md and …`). For a folder outside
  every listed repo, pass its absolute path. A name that is neither: ask the user for the folder, never guess one.
- `<account>`: an account key from `sessions.conf`; leave it out for the default (the first one listed).
- `<prompt-file>`: only when there is a first prompt (anything after "—" in the request, or the handoff
  instruction). Write the prompt with the Write tool to a file in your temporary or scratchpad directory first
  (no quotes in its path), then pass that path; no quote inside the prompt can break the command.
- The script prints `opened: account <key>, pid <n>, in <folder>` once the new `claude` process is running there,
  or exits 1 with `NOT CONFIRMED`. Report what it printed; never say a session opened without the `opened:` line.

Invoked by Claude rather than typed: only when the user asked in this conversation for a new session or a handoff
to one, at the moment they asked for (e.g. "when the tests finish"). Say in the reply that it was opened, where,
under which account, and with what first prompt.

Request: $ARGUMENTS
