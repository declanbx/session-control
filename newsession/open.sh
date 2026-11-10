#!/usr/bin/env bash
# Open a new Terminal.app window running Claude Code at a project's root, then confirm the new session started.
#
#   open.sh <repo> [<account>] [<prompt-file>]
#   open.sh --list                         print the repos and accounts read from sessions.conf
#   open.sh --dry-run <repo> [<account>] [<prompt-file>]   print the command the window would run, open nothing
#   open.sh --keys | --root <repo> | --cmd [<account>]      lookups for the terminal shortcuts (shell/shortcuts.zsh)
#
# <repo>         a repo key or alias from sessions.conf, or an absolute folder path. A path inside a listed repo is
#                moved up to that repo's root, so a session always starts where the project's CLAUDE.md and
#                .claude/settings.json live. A folder outside every listed repo is used as given.
# <account>      an account key from sessions.conf; omitted, the first account listed is used.
# <prompt-file>  a file whose text becomes the new session's first prompt.
#
# sessions.conf sits beside this script (set SESSIONS_CONF to read another file).
set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CONF="${SESSIONS_CONF:-$HERE/sessions.conf}"
[[ -f $CONF ]] || { echo "no config at $CONF: copy sessions.conf.example to sessions.conf and edit it" >&2; exit 2; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
phys()  { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }   # resolve .. and symlinks, as lsof reports cwd

# ---- read sessions.conf: "repo <key>[,<alias>...] = <folder>" and "account <key> = <command>" ----
REPO_KEYS=(); REPO_DIRS=(); ACCT_KEYS=(); ACCT_CMDS=()
re='^[[:space:]]*(repo|account)[[:space:]]+([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$'
skip='^[[:space:]]*(#|$)'
keyre='^[a-z0-9_][a-z0-9_.-]*(,[a-z0-9_][a-z0-9_.-]*)*$'
n=0
while IFS= read -r line || [[ -n $line ]]; do
  n=$((n + 1))
  [[ $line =~ $skip ]] && continue
  [[ $line =~ $re ]] || { echo "sessions.conf line $n: expected 'repo <key> = <folder>' or 'account <key> = <command>'" >&2; exit 2; }
  kind=${BASH_REMATCH[1]}; key=$(lower "${BASH_REMATCH[2]}"); val=${BASH_REMATCH[3]}
  [[ $key =~ $keyre ]] || { echo "sessions.conf line $n: keys use letters, digits, _ . - (aliases after commas): $key" >&2; exit 2; }
  if [[ $kind == repo ]]; then
    val=${val/#\~/$HOME}; val=${val//\$HOME/$HOME}; val=${val%/}
    [[ $val == /* ]] || { echo "sessions.conf line $n: folder must be absolute or start with \$HOME/ or ~/: $val" >&2; exit 2; }
    [[ $val != *[\"\$\`]* ]] || { echo "sessions.conf line $n: folder may not contain \", \$ or \`: $val" >&2; exit 2; }
    REPO_KEYS+=("$key"); REPO_DIRS+=("$(phys "$val")")
  else
    ACCT_KEYS+=("$key"); ACCT_CMDS+=("$val")
  fi
done < "$CONF"
[[ ${#ACCT_KEYS[@]} -gt 0 ]] || { echo "sessions.conf lists no account; add: account default = claude" >&2; exit 2; }

root_of() {  # repo key or path -> folder (a path inside a listed repo snaps to the deepest such repo's root)
  local a="$1" lc i k r rl al best=""
  lc=$(lower "$a")
  for i in "${!REPO_KEYS[@]}"; do
    IFS=',' read -r -a k <<< "${REPO_KEYS[$i]}"
    for r in "${k[@]}"; do [[ $lc == "$r" ]] && { echo "${REPO_DIRS[$i]}"; return; }; done
  done
  [[ $a == /* || $a == ~* ]] || { echo "unknown repo: $a (listed: ${REPO_KEYS[*]}; or pass a folder path)" >&2; return 1; }
  a="${a/#\~/$HOME}"
  [[ -d $a ]] || { echo "no such folder: $a" >&2; return 1; }
  a=$(phys "$a"); al=$(lower "$a")
  for r in "${REPO_DIRS[@]}"; do
    rl=$(lower "$r")
    if [[ ( $al == "$rl" || $al == "$rl"/* ) && ${#r} -gt ${#best} ]]; then best=$r; fi
  done
  [[ -n $best ]] && { echo "$best"; return; }
  [[ $a != *[\"\$\`]* ]] || { echo "folder may not contain \", \$ or \`: $a" >&2; return 1; }
  echo "${a%/}"
}

cmd_of() {  # account key (empty = the default, listed first) -> its command
  local want i; want=$(lower "${1:-${ACCT_KEYS[0]}}")
  for i in "${!ACCT_KEYS[@]}"; do [[ ${ACCT_KEYS[$i]} == "$want" ]] && { echo "${ACCT_CMDS[$i]}"; return; }; done
  echo "unknown account: $want (listed: ${ACCT_KEYS[*]})" >&2; return 1
}

# Lookups, used by the terminal shortcuts (shell/shortcuts.zsh) and for checking sessions.conf.
case ${1-} in
  --list)
    for i in "${!REPO_KEYS[@]}"; do printf 'repo     %-20s %s\n' "${REPO_KEYS[$i]}" "${REPO_DIRS[$i]}"; done
    for i in "${!ACCT_KEYS[@]}"; do printf 'account  %-20s %s%s\n' "${ACCT_KEYS[$i]}" "${ACCT_CMDS[$i]}" "$([[ $i == 0 ]] && echo '   (default)')"; done
    exit 0 ;;
  --keys) for k in "${REPO_KEYS[@]}"; do tr ',' '\n' <<< "$k"; done; exit 0 ;;
  --root) root_of "${2:?usage: open.sh --root <repo>}"; exit ;;
  --cmd)  cmd_of "${2-}"; exit ;;
esac
DRY=0; [[ ${1-} == --dry-run ]] && { DRY=1; shift; }

DIR=$(root_of "${1:?usage: open.sh <repo|folder> [account] [prompt-file]   (open.sh --list shows the choices)}") || exit 2
[[ -d $DIR ]] || { echo "folder for '$1' does not exist: $DIR" >&2; exit 2; }
ACCT=$(lower "${2:-${ACCT_KEYS[0]}}")
CMD=$(cmd_of "$ACCT") || exit 2

P="${3:-}"
if [[ -n $P ]]; then
  [[ -s $P ]] || { echo "prompt file missing or empty: $P" >&2; exit 2; }
  [[ $P != *"'"* && $P != *'"'* ]] || { echo "prompt file path may not contain quotes: $P" >&2; exit 2; }
fi

# The line Terminal types into its new window, whose interactive shell loads your aliases. The prompt is read from
# the file there, so no quote inside it can break this command.
LINE="cd \"$DIR\" && $CMD"
[[ -n $P ]] && LINE+=" \"\$(cat '$P')\""
if [[ $DRY == 1 ]]; then echo "$LINE"; exit 0; fi
AS=${LINE//\\/\\\\}; AS=${AS//\"/\\\"}   # escape for an AppleScript string literal

before=$(pgrep -x claude | sort)
osascript -e "tell application \"Terminal\" to do script \"$AS\"" -e 'tell application "Terminal" to activate' >/dev/null || {
  echo "osascript failed (allow your terminal to control Terminal.app in System Settings > Privacy & Security > Automation)" >&2; exit 1; }

# Confirm: a claude process that was not running before, whose working directory is DIR.
for _ in $(seq 1 20); do
  sleep 1
  for pid in $(comm -13 <(echo "$before") <(pgrep -x claude | sort)); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
    if [[ $(lower "$cwd") == $(lower "$DIR") ]]; then
      echo "opened: account $ACCT, pid $pid, in $DIR${P:+, first prompt from $P}"; exit 0
    fi
  done
done
echo "NOT CONFIRMED: no new claude process in $DIR after 20 s. Look at the new Terminal window." >&2
exit 1
