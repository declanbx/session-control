# session-control

Two Claude Code skills that let Claude open and close sessions in separate Terminal windows, plus optional
one-word terminal shortcuts for starting a session yourself:

- **`/newsession`** opens a new Claude Code session in its own Terminal window, in the project you name, under the
  account you name, optionally with a first prompt. Use it to start a fresh session without leaving the one you
  are in, or to have one session hand a task to another.
- **`/closesession`** ends the session you are talking to and closes its Terminal window, after a delay long enough
  to read its last message.

Requires macOS, Terminal.app and Claude Code.

## Install

```bash
git clone https://github.com/declanbx/session-control.git ~/session-control
mkdir -p ~/.claude/skills
ln -s ~/session-control/newsession   ~/.claude/skills/newsession
ln -s ~/session-control/closesession ~/.claude/skills/closesession
cp ~/session-control/newsession/sessions.conf.example ~/session-control/newsession/sessions.conf
```

Then edit `sessions.conf`: one line per project folder and one per Claude account.

```
repo thesis,phd = $HOME/Documents/thesis
repo website    = $HOME/code/website

account default = claude
account work    = CLAUDE_CONFIG_DIR=$HOME/.claude-work claude
```

- **Repos:** a short key (plus optional aliases after commas) and the project's folder. Keys use letters, digits,
  `_`, `.` and `-`. Folders are absolute or start with `$HOME/` or `~/`; spaces are fine without quotes.
- **Accounts:** a short key and the command that starts Claude. The first account is the default. With one
  account, keep only `default`.

Check what the script read with `~/.claude/skills/newsession/open.sh --list`. `git pull` updates both skills and
never touches `sessions.conf`.

The first time a session opens, macOS may ask to let your terminal control Terminal.app. Allow it.

## Use

Type the command, or ask in plain words:

| You type | What happens |
|---|---|
| `/newsession thesis` | A new window in the `thesis` folder, running your default account |
| `/newsession website work` | A new window in the `website` folder, running the `work` account |
| `/newsession website work — fix the broken contact form and report back` | The same, with that text as the new session's first prompt |
| "hand this off to a new session in my thesis folder" | Claude writes the handoff prompt and opens the window |
| `/closesession` | This session ends and its window closes in 60 seconds |
| `/closesession 5m` · "close yourself when you're done" | The same, after five minutes, or after Claude's last message |

Claude acts only when you ask, but it can act on a plain request: you don't have to type the command. It confirms
the new `claude` process is running before saying a session opened, and says when a close is scheduled before it
happens. To cancel a scheduled close, run `pkill -f close_session.sh`.

Do not add `disable-model-invocation: true` to either skill's header. That setting means only you can start the
skill by typing it, so a request like "hand this off to a new session when the tests finish" silently does nothing.

## More than one Claude account

Claude Code keeps each account's login, settings and skills in one config folder, `~/.claude` by default. Setting
`CLAUDE_CONFIG_DIR` points it at another folder, which gives you a second account that is logged in separately.

1. Run `CLAUDE_CONFIG_DIR=$HOME/.claude-work claude` once and log in with the second account.
2. Add it to `sessions.conf`: `account work = CLAUDE_CONFIG_DIR=$HOME/.claude-work claude`.
3. Make both skills available inside that account too, since each account reads skills from its own folder:

   ```bash
   mkdir -p ~/.claude-work/skills
   ln -s ~/session-control/newsession   ~/.claude-work/skills/newsession
   ln -s ~/session-control/closesession ~/.claude-work/skills/closesession
   ```

A shell alias works in the command column as well. With `alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'`
in your shell's startup file, the line can be `account work = claude-work`.

## Terminal shortcuts (optional, zsh)

The same `sessions.conf` can give your own terminal a command per project, so a fresh Terminal window needs one
word instead of `cd "<long path>" && claude`. Add this line to `~/.zshrc`, after any aliases your account commands
use, and open a new window:

```zsh
source ~/session-control/shell/shortcuts.zsh
```

| You type in Terminal | What happens in that window |
|---|---|
| `thesis` | Goes to the `thesis` folder and starts Claude with the default account |
| `thesis work` | The same, with the `work` account |
| `thesis work --resume` · `thesis default "fix the build"` | Anything after the account goes to Claude unchanged, a quoted first prompt included |

A word after the project name that is not an account (`thesis wrok`) stops with the list of accounts, so a typo
never reaches Claude as a prompt. A project key that is already a command in your shell (`ls`, `git`) gets no
shortcut, and the shell says so when it starts.

## How it works

**Opening.** `newsession/open.sh` looks the project and account up in `sessions.conf` and asks Terminal.app, through
`osascript`, to open a window and type `cd "<folder>" && <command>` into it. A first prompt is written to a file and
passed as `"$(cat <file>)"`, so quotes or special characters in it cannot break the command. A path inside a listed
project is moved up to that project's root, so a session always starts where the project's `CLAUDE.md` and
`.claude/settings.json` live. The script then waits up to 20 seconds for a new `claude` process whose working
folder is that root, and reports `opened:` or `NOT CONFIRMED`. `open.sh --dry-run <repo> [account]` prints the
command without opening anything.

**Closing.** The session finds its own `claude` process by walking up the parent chain from its shell, and its
Terminal window by that process's tty. `closesession/close_session.sh` then runs detached: it waits out the delay,
ends the `claude` process (`TERM`, then `KILL` if ignored), and closes that one window without a save prompt. It
closes nothing if the window is already gone, and logs each step to `/tmp/closesession.log`.

To use another terminal app (iTerm2, Ghostty and others), replace the `osascript` calls in `open.sh` and
`close_session.sh` with that app's equivalent.

**Upgrading from `newsession`:** the repos and accounts tables that used to sit inside `SKILL.md` now live in
`sessions.conf`. Copy your entries across in the new format, then replace the old skill folder with the link above.

## License

MIT
