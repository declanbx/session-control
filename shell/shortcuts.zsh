# session-control terminal shortcuts (optional, zsh).
#
# Turns every repo key and alias in newsession/sessions.conf into a command for your own terminal:
#
#   thesis                     go to the thesis folder and start Claude with the default account
#   thesis work                the same with the `work` account
#   thesis work --resume       anything after the account goes to Claude unchanged, a quoted first prompt included
#
# This runs Claude in the window you typed it in; /newsession opens a new window instead. Both read the same
# sessions.conf. Enable by adding this line to ~/.zshrc, after any aliases your account commands use:
#
#   source ~/session-control/shell/shortcuts.zsh

_sc_open=${${(%):-%x}:A:h:h}/newsession/open.sh

# _sc_launch <repo> [<account>] [claude args...]
_sc_launch() {
  local repo=$1 dir cmd
  shift
  if [[ -n ${1-} && $1 != -* ]]; then
    cmd=$("$_sc_open" --cmd "$1") || return 2   # a word that is not an account stops here, so a typo never
    shift                                        # reaches Claude as a prompt
  else
    cmd=$("$_sc_open" --cmd "") || return 2
  fi
  dir=$("$_sc_open" --root "$repo") || return 2
  cd "$dir" || return
  eval "$cmd"' "$@"'   # eval, so a command that is a shell alias expands like a typed one
}

() {
  local key keys
  keys=$("$_sc_open" --keys) || return
  for key in ${(f)keys}; do
    case $(whence -w -- $key) in
      *": none") ;;
      *": function") [[ $(functions -- $key) == *_sc_launch* ]] || {
        print -u2 "session-control: '$key' is already a function here; no shortcut added"; continue; } ;;
      *) print -u2 "session-control: '$key' is already a command here; no shortcut added"; continue ;;
    esac
    eval "function $key { _sc_launch $key \"\$@\" }"   # keys are letters, digits, _ . - only (open.sh checks)
  done
}
