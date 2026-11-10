#!/bin/zsh
# close_session.sh — end THIS Claude session and close its Terminal window, after a delay.
#
# Detached on purpose: it must outlive the claude process it is going to kill, so it is launched
# with nohup and reparented to launchd. Everything it needs is resolved by the CALLER and passed in,
# because by the time it fires the process it would have queried is gone.
#
#   close_session.sh <delay_seconds> <claude_pid> <terminal_window_id> [log]
set -u
DELAY=${1:?delay_seconds}; PID=${2:?claude_pid}; WID=${3:?terminal_window_id}
LOG=${4:-/dev/null}
print "[closesession] fire in ${DELAY}s  claude_pid=$PID  terminal_window=$WID  at $(date -u +%FT%TZ)" >>"$LOG"

sleep "$DELAY"

# 1. the claude process first, so Terminal has no running job to prompt about
if kill -0 "$PID" 2>/dev/null; then
  kill -TERM "$PID" 2>/dev/null
  for i in {1..10}; do kill -0 "$PID" 2>/dev/null || break; sleep 0.5; done
  kill -0 "$PID" 2>/dev/null && kill -KILL "$PID" 2>/dev/null
  print "[closesession] claude $PID ended" >>"$LOG"
else
  print "[closesession] claude $PID already gone" >>"$LOG"
fi
sleep 1

# 2. the window. `saving no` suppresses the save sheet; the process is already gone so Terminal
#    has nothing to ask about. Guarded so a wrong/stale id closes nothing rather than something else.
osascript >>"$LOG" 2>&1 <<AS
tell application "Terminal"
  repeat with w in windows
    if (id of w) is ${WID} then
      close w saving no
      return "closed window ${WID}"
    end if
  end repeat
  return "window ${WID} not found - nothing closed"
end tell
AS
print "[closesession] done $(date -u +%FT%TZ)" >>"$LOG"
