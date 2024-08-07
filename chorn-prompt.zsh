#----------------------------------------------------------------------------
typeset -gA _prompt
typeset -gA _prompt_lang_cache
#-----------------------------------------------------------------------------
_language_version() {
  local language=$1

  (( $+commands[mise] )) && eval "$(mise hook-env --quiet --shell zsh)"
  (( $+commands[direnv] )) && eval "$(direnv export zsh)"

  [[ "$language" == "rust" ]] && language=rustc
  if (( ! $+commands[$language] )); then
    echo 'n/i'
    return 0
  fi

  case "$language" in
    clojure)
      clojure -M -e "(clojure-version)" | tr -d '"'
      ;;
    crystal)
      crystal --version | grep '^Crystal' | awk '{ print $2 }'
      ;;
    go|golang)
      go version |& sed -e 's/^go version go//' -e 's/ .*$//'
      ;;
    elixir)
      elixir --version |& grep '^Elixir' | awk '{print $2}'
      ;;
    elm)
      elm --version
      ;;
    java)
      java -version |& grep 'openjdk version' | sed -e 's/^.* "//' -e 's/" .*//'
      ;;
    node)
      node --version | sed -e 's/^v//'
      ;;
    protoc)
      protoc --version | awk '{ print $2 }'
      ;;
    python)
      python --version |& awk '{print $2}'
      ;;
    python2)
      python2 --version |& awk '{print $2}'
      ;;
    python3)
      python3 --version |& awk '{print $2}'
      ;;
    ruby)
      ruby --version | awk '{print $2}'
      ;;
    rustc)
      rustc --version |& awk '{print $2}'
      ;;
    swift)
      swift --version | grep '^Apple' | awk '{ print $4 }'
      ;;

    *)
      ;;
  esac
}
#-----------------------------------------------------------------------------
_prompt_reset() {
  print -n "%f%b%k%u%s"
}
#-----------------------------------------------------------------------------
_prompt_update_git() {
  local _git_dir=${1:=.git}
  local _work_tree=${2:=.}

  typeset -A g=(staged 0 conflicts 0 changed 0 untracked 0 ignored 0 no_repository 0 clean 0 deleted 0)

  while read -rA _status ; do
    case "${_status[1]}" in
      fatal*)
        g[no_repository]=1
        ;;
      \#)
        case "${_status[2]}" in
          branch.oid)
            g[oid]="${_status[3]:0:8}"
            ;;
          branch.head)
            g[branch]="${_status[3]}"
            ;;
          branch.upstream)
            g[upstream]="${_status[3]}"
            ;;
          branch.ab)
            g[ahead]=$((${_status[3]}))
            g[behind]=$((${_status[4]}))
            ;;
        esac
        ;;
      \?)
        (( g[untracked]++ ))
        ;;
      \!)
        (( g[ignored]++ ))
        ;;
      1)
        case "${_status[2]}" in
          .M)
            (( g[changed]++ ))
            ;;
          .D)
            (( g[deleted]++ ))
            ;;
          A.|M.)
            (( g[staged]++ ))
            ;;
        esac
        ;;
      2)
        case "${_status[2]}" in
          R.)
            (( g[changed]++ ))
            ;;
        esac
        ;;
    esac
  done < <(git --git-dir="${_git_dir}" --work-tree="${_work_tree}" status --porcelain=2 --branch 2>&1)

  if (( g[changed] == 0 && g[conflicts] == 0 && g[staged] == 0 && g[untracked] == 0 && g[deleted] == 0)) ; then
    g[clean]='yes_but_no_value_to_show'
  fi

  typeset -p g
}
#-----------------------------------------------------------------------------
function _prompt_print_git_fragment() {
  local theme=${_prompt_git_theme[$1]}
  local show=${_prompt_git_theme[show_${1}_count]}
  local value=${g[$1]}

  [[ -n "$theme" ]] || return
  [[ "${show:=1}" == "1" ]] || return
  [[ "$value" == "0" ]] && return

  print -n "$theme"
  _prompt_reset

  [[ -z "$value" || "$value" == "yes_but_no_value_to_show" ]] && return
  print -n "$value"
}
#-----------------------------------------------------------------------------
_prompt_git() {
  (( $+commands[git] )) || return
  local _git_dir=${1:=.git}
  local _work_tree=${2:=.}

   [[ -d "$_git_dir" && -d "$_work_tree" ]] || return

  eval "$(_prompt_update_git "$_git_dir" "$_work_tree")"

  (( g[no_repository] == 1 )) && return

  for element in prefix branch behind ahead separator oid separator staged conflicts changed untracked deleted clean suffix ; do
    _prompt_print_git_fragment "$element"
  done
}
#-----------------------------------------------------------------------------
_prompt_time() {
  print -n "%F{8}%D{%H:%M:%S}"
}
#-----------------------------------------------------------------------------
ps_owners() {
  local _pid=${1:-$$}

  [[ "$_pid" -eq 0 ]] && return
  (( $+commands[ps] )) || return

  read -r _uid _user _ppid _command < <(ps -o uid=,user=,ppid=,command= -p "$_pid")

  echo "$_pid $_user $_uid $_ppid \"$_command\""

  ps_owners "$_ppid"
}

am_i_someone_else() {
  (( $+commands[pgrep] )) || return 0
  pgrep -u 0 >&/dev/null || return 1
  [[ "$EUID" -eq 0 ]] && return 1

  local -a _owners
  local -A _counts

  while read -r _pid _user _uid _ppid _command; do
    if [[ -z "${_counts[$_user]}" ]]; then
      _owners+=("$_user")
      _counts[$_user]=1
    else
      ((_counts[$_user]++))
    fi
  done < <(ps_owners)

  [[ "${#_owners[@]}" -le 2 && "${_owners[-1]}" == "root" ]] && return 1
}

_prompt_user() {
  am_i_someone_else && print -n '%F{9}_%n_'
}
#-----------------------------------------------------------------------------
_prompt_host() {
  if [[ -n "$SSH_TTY" ]] ; then
    print -n '%F{15}@%F{14}%m'
  fi
}
#-----------------------------------------------------------------------------
_prompt_path() {
  print -n '%F{7}%~'
}
#-----------------------------------------------------------------------------
_prompt_lastexit() {
  print -n ' %(?.%F{7}.%F{15})%? %(!.#.$)'
}
#-----------------------------------------------------------------------------
_prompt_gitconfigs() {
  [[ -n "${(k)_prompt_extra_git[@]}" ]] || return

  for _extra in "${(k)_prompt_extra_git[@]}"; do
    local _gd=${_prompt_extra_git[${_extra}]}
    local _wt=$(dirname "$_gd")

    [[ "$_wt" == "$PWD" ]] || continue
    [[ -d "$_gd" && -d "$_wt" ]] || continue

    print -n " %F{8}${_extra}:%f"
    _prompt_git "$_gd" "$_wt"
  done
}
#-----------------------------------------------------------------------------
_async_prompt_language() {
  builtin cd -q "$1"
  local _language=$2

  [[ -n "$_language" ]] || return

  echo "_prompt_lang_cache[${_language}]=\"%F{6}${_language}-$(_language_version "$_language" 2>/dev/null)\""
}
#-----------------------------------------------------------------------------
_async_prompt_git() {
  builtin cd -q "$1"
  echo "_prompt[git]=\"$(_prompt_git 2>/dev/null)\""
}
#-----------------------------------------------------------------------------
_async_prompt_gitconfigs() {
  builtin cd -q "$1"
  echo "_prompt[gitconfigs]=\"$(_prompt_gitconfigs 2>/dev/null)\""
}
#-----------------------------------------------------------------------------
_chorn_prompt_precmd() {
  _async_init

  async_job 'prompt_worker' _async_prompt_git "$PWD"
  async_job 'prompt_worker' _async_prompt_gitconfigs "$PWD"

  [[ -n "${_prompt_languages[@]}" ]] || return

  for _language in ${_prompt_languages[@]} ; do
    async_job 'prompt_worker' _async_prompt_language "$PWD" "$_language"
  done
}
#-----------------------------------------------------------------------------
_chorn_left_prompt() {
  local -a _line1=()
  local -a _line2=()

  _prompt[time]="$(_prompt_time)"
  _prompt[user]="$(_prompt_user)"
  _prompt[host]="$(_prompt_host)"
  _prompt[path]="$(_prompt_path)"

  for _language in ${_prompt_languages[@]} ; do
    [[ -n "${_prompt_lang_cache[$_language]}" ]] && _line1+=("${_prompt_lang_cache[$_language]}")
  done

  for piece in git gitconfigs ; do
    [[ -n "${_prompt[$piece]}" ]] && _line1+=("${_prompt[$piece]}")
  done

  for piece in time user host path ; do
    [[ -n "${_prompt[$piece]}" ]] && _line2+=("${_prompt[$piece]}")
  done

  if (( ${#_line1[@]} > 0 )) ; then
    _prompt_reset
    print "${_line1[@]}"
    _prompt_reset
  fi

  _prompt_reset
  print -n "${_line2[@]}"
  _prompt_lastexit # Like this or $? is wrong
  _prompt_reset
  print -n ' '
}
#-----------------------------------------------------------------------------
#The callback_function is called with the following parameters:
# $1 job name, e.g. the function passed to async_job
# $2 return code
#    Returns -1 if return code is missing, this should never happen, if it
#    does, you have likely run into a bug. Please open a new issue with a
#    detailed description of what you were doing.
# $3 resulting (stdout) output from job execution
# $4 execution time, floating point e.g. 0.0076138973 seconds
# $5 resulting (stderr) error output from job execution
# $6 has next result in buffer (0 = buffer empty, 1 = yes)
#    This means another async job has completed and is pending in the buffer,
#    it's very likely that your callback function will be called a second time
#    (or more) in this execution. It's generally a good idea to e.g. delay
#    prompt updates (zle reset-prompt) until the buffer is empty to prevent
#    strange states in ZLE.
#
_async_prompt_callback() {
  local _job=$1
  local _return_code=$2
  local _stdout=$3
  local _time=$4
  local _stderr=$5
  local _next=$6

  if [[ -n "$DEBUG_CHORN_PROMPT" ]] ; then
    {
      echo
      echo "PWD           $PWD"
      echo "_job          $1"
      echo "_return_code  $2"
      echo "_stdout       $3"
      echo "_time         $4"
      echo "_stderr       $5"
      echo "_next         $6"
      echo "ZLE_STATE     $ZLE_STATE"
      echo
    } >> "$HOME/debug_chorn_prompt.log"
  fi

  [[ -n "$_stdout" ]] && eval "$_stdout"

  (( _next == 0 )) && zle && zle .reset-prompt && zle -R
}
#-----------------------------------------------------------------------------
_async_init() {
  [[ -n "${ASYNC_CALLBACKS[prompt_worker]}" ]] || prompt_chorn_setup_done=0
  ((${prompt_chorn_setup_done})) && return

  async
  async_stop_worker 'prompt_worker' || true
  async_start_worker 'prompt_worker' -n
  async_register_callback 'prompt_worker' _async_prompt_callback
  prompt_chorn_setup_done=1
}
#-----------------------------------------------------------------------------
prompt_chorn_setup() {
  typeset -g prompt_chorn_setup_done=0

  autoload -Uz colors && colors
  autoload -Uz add-zsh-hook
  autoload -Uz async

  if ! typeset -f async >&/dev/null ; then
    echo "ERROR: 'async' must be in your fpath from the 'zsh-async' project: https://github.com/mafredri/zsh-async"
    return
  fi

  if ! typeset -p _preferred_languages >&/dev/null ; then
    typeset -g -a _preferred_languages=(ruby node python)
  fi

  if ! typeset -p _prompt_git_theme >&/dev/null ; then
    typeset -g -A _prompt_git_theme=(
      prefix '('
      suffix ')'
      separator '|'
      branch '%{$fg_bold[magenta]%}'
      clean '%{$fg_bold[green]%}%{✔%G%}'
      changed '%{$fg[blue]%}%{✚%G%}'
      staged '%{$fg[red]%}%{●%G%}'
      conflicts '%{$fg[red]%}%{✖%G%}'
      oid '%{$fg[gray]%}'
      ahead '%{↑%G%}'
      behind '%{↓%G%}'
      untracked '%{…%G%}'
      deleted '%{$fg[red]%}%{ᛞ⃠%G%}'
      show_changed_count 1
      show_staged_count 1
      show_conflict_count 1
      show_ahead_count 1
      show_behind_count 1
      show_untracked_count 0
    )
  fi

  add-zsh-hook precmd _chorn_prompt_precmd

  prompt_opts=(cr percent sp subst)

  PROMPT='$(_chorn_left_prompt)'
}
#-----------------------------------------------------------------------------
prompt_chorn_setup "$@"
#-----------------------------------------------------------------------------
# vim: set syntax=zsh ft=zsh sw=2 ts=2 expandtab:
