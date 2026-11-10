---
name: closesession
description: Use when the user types /closesession, or asks Claude to close, end, quit or shut down this session and its Terminal window (e.g. "close yourself when you're done", "shut this session down in 5 minutes"). Ends THIS session only. Not for closing a different session, and not for merely finishing a task.
argument-hint: "[delay, e.g. 30s or 5m; default 60s]"
---

# Close this session and its Terminal window, after a delay

Schedule the end of **your own** session: a detached timer kills this `claude` process and closes the Terminal
window it is running in. The delay exists so your final message stays on screen long enough to read: **default 60
seconds**, or the delay the user names (`/closesession 5m` → 300).

Then write your closing message and stop. Do not do more work after scheduling.

## The three facts you need, resolved in this order

Resolve everything **now** and pass it to the script as arguments. By the time the timer fires, the process you
would have queried is gone.

**1. Your own `claude` process id.** Walk up the parent chain from a shell you spawn until you reach the process
whose command is `claude` and whose tty is a real `ttysNNN`. The Bash tool's own shell has tty `??`, so you cannot
read it directly.

```bash
# Check the comm of the CURRENT pid and take THAT pid. Taking $ppid here is an off-by-one that returns claude's
# parent (the login shell); that also ends the session, which is what makes the bug easy to miss.
pid=$$; CLAUDE_PID=""; CLAUDE_TTY=""
while [ -n "$pid" ] && [ "$pid" != "1" ]; do
  comm=$(ps -o comm= -p "$pid" 2>/dev/null)
  tty=$(ps -o tty=  -p "$pid" 2>/dev/null | tr -d ' ')
  case "$(basename "${comm:-}")::${tty}" in
    claude::ttys*) CLAUDE_PID=$pid; CLAUDE_TTY=$tty; break ;;
  esac
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -n "$CLAUDE_PID" ] || { echo "no claude ancestor with a real tty — stop, tell the user"; exit 1; }
echo "$CLAUDE_PID $(ps -o comm= -p "$CLAUDE_PID") /dev/$CLAUDE_TTY"
```

**Read the printed line before you trust it:** the command must be exactly `claude`.

**2. The Terminal window id**, from the tty. Terminal exposes `tty` on each tab:

```bash
osascript -e "tell application \"Terminal\" to return id of first window whose tty of its selected tab is \"/dev/$CLAUDE_TTY\""
```

**3. Sanity-check before you arm it.** The resolved pid must be an **ancestor of your own shell**; that is what
makes it *your* session. Several `claude` processes may be running, and picking the wrong one ends someone else's
session. If the walk did not find a `claude` ancestor with a real tty, **stop and tell the user** rather than
guessing.

## Arm it

```bash
DELAY=60   # seconds; the delay the user named, if any
nohup "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/closesession/close_session.sh" \
  "$DELAY" "$CLAUDE_PID" "$WINDOW_ID" /tmp/closesession.log >/dev/null 2>&1 &
disown
```

`nohup` and `&` are load-bearing: the script has to outlive the process it is about to kill. It sleeps, sends
`TERM` (then `KILL` if that is ignored), waits for the process to go, and only then closes the window with
`close w saving no`, in that order, because Terminal asks before closing a window with a running process but
closes one with no job silently.

## Then

Say in your final message **what you scheduled and when it fires**, in one line, and stop. That message is the last
thing the user sees, so put the substance of your turn above it.

## Boundaries

- **This session only.** Never target another session's pid or window; if the user wants a different session
  closed, say so and let them do it there.
- **Never schedule this unasked.** Finishing a task is not a reason to close the window.
- **Say it is armed.** A session that disappears without having said it would is a bug, not a feature.
- If something is still running that the user would want to see finish (a background job, a build, a remote job
  you are waiting on), **say so and ask** before arming it.
- To cancel after arming: `pkill -f close_session.sh`.

Request: $ARGUMENTS
