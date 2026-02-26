# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - Midnight Soothing Edition
# Optimized for night-time use with low-contrast, muted colors.

### Segment drawing
CURRENT_BG='NONE'

# Characters
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"

# Begin a segment
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components

# Context: user@hostname (Very dark grey background, muted teal text)
prompt_context() {
  if [[ -n "$SSH_CLIENT" ]]; then
    prompt_segment 237 109 "%B%(!.%F{131}.%F{15})%n%F{109}@%m%b"
  else
    prompt_segment 237 109 "%B%(!.%F{131}.%F{15})%n%b ~"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR="$BRANCH"
  }
  local ref dirty mode repo_path clean has_upstream
  local modified untracked added deleted tagged stashed
  local ready_commit git_status bgclr fgclr
  local commits_diff commits_ahead commits_behind has_diverged to_push to_pull

  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    git_status=$(git status --porcelain 2> /dev/null)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    
    # Unified background for the whole Git segment to reduce visual noise
    bgclr='237' # Dark slate grey
    
    if [[ -n $dirty ]]; then
      clean=''
      fgclr='146' # Soft grey-blue text for dirty branch name
    else
      clean=' ✔'
      fgclr='108' # Muted sage green text for clean branch name
    fi

    local upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)
    if [[ -n "${upstream}" && "${upstream}" != "@{upstream}" ]]; then has_upstream=true; fi
    local current_commit_hash=$(git rev-parse HEAD 2> /dev/null)

    local number_of_untracked_files=$(\grep -c "^??" <<< "${git_status}")
    if [[ $number_of_untracked_files -gt 0 ]]; then untracked=" %F{136}$number_of_untracked_files☀%F{$fgclr}"; fi # Muted gold

    local number_added=$(\grep -c "^A" <<< "${git_status}")
    if [[ $number_added -gt 0 ]]; then added=" %F{108}$number_added✚%F{$fgclr}"; fi # Muted green

    local number_modified=$(\grep -c "^.M" <<< "${git_status}")
    if [[ $number_modified -gt 0 ]]; then
      modified=" %F{131}$number_modified●%F{$fgclr}" # Soft rust
    fi

    local number_added_modified=$(\grep -c "^M" <<< "${git_status}")
    local number_added_renamed=$(\grep -c "^R" <<< "${git_status}")
    if [[ $number_modified -gt 0 && $number_added_modified -gt 0 ]]; then
      modified="$modified$((number_added_modified+number_added_renamed))±"
    elif [[ $number_added_modified -gt 0 ]]; then
      modified=" %F{131}●$((number_added_modified+number_added_renamed))±%F{$fgclr}"
    fi

    local number_deleted=$(\grep -c "^.D" <<< "${git_status}")
    if [[ $number_deleted -gt 0 ]]; then
      deleted=" %F{095}$number_deleted‒%F{$fgclr}" # Muted mauve/plum
    fi

    local number_added_deleted=$(\grep -c "^D" <<< "${git_status}")
    if [[ $number_deleted -gt 0 && $number_added_deleted -gt 0 ]]; then
      deleted="$deleted$number_added_deleted±"
    elif [[ $number_added_deleted -gt 0 ]]; then
      deleted=" %F{095}‒$number_added_deleted±%F{$fgclr}"
    fi

    local tag_at_current_commit=$(git describe --exact-match --tags $current_commit_hash 2> /dev/null)
    if [[ -n $tag_at_current_commit ]]; then tagged=" ☗$tag_at_current_commit "; fi

    local number_of_stashes="$(git stash list -n1 2> /dev/null | wc -l)"
    if [[ $number_of_stashes -gt 0 ]]; then
      stashed=" %F{066}${number_of_stashes##*(  )}⚙%F{$fgclr}" # Muted teal
    fi

    if [[ $number_added -gt 0 || $number_added_modified -gt 0 || $number_added_deleted -gt 0 ]]; then ready_commit=' ⚑'; fi

    local upstream_prompt=''
    if [[ $has_upstream == true ]]; then
      commits_diff="$(git log --pretty=oneline --topo-order --left-right ${current_commit_hash}...${upstream} 2> /dev/null)"
      commits_ahead=$(\grep -c "^<" <<< "$commits_diff")
      commits_behind=$(\grep -c "^>" <<< "$commits_diff")
      upstream_prompt="$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)"
      upstream_prompt=$(sed -e 's/\/.*$/ ☊ /g' <<< "$upstream_prompt")
    fi

    has_diverged=false
    if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then has_diverged=true; fi
    if [[ $has_diverged == false && $commits_ahead -gt 0 ]]; then
      to_push=" %F{103}↑$commits_ahead%F{$fgclr}" # Pale slate
    fi
    if [[ $has_diverged == false && $commits_behind -gt 0 ]]; then 
      to_pull=" %F{139}↓$commits_behind%F{$fgclr}" # Soft purple
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    prompt_segment $bgclr $fgclr
    print -n "${ref/refs\/heads\//$PL_BRANCH_CHAR $upstream_prompt}${mode}$to_push$to_pull$clean$tagged$stashed$untracked$modified$deleted$added$ready_commit"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        prompt_segment 237 131 # Dark slate, soft rust
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        prompt_segment 237 136 # Dark slate, muted gold
        st='±'
      else
        prompt_segment 237 108 # Dark slate, sage green
      fi
      print -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -q "^\?"`; then
        prompt_segment 237 131
        st='±'
      elif `hg st | grep -q "^[MA]"`; then
        prompt_segment 237 136
        st='±'
      else
        prompt_segment 237 108
      fi
      print -n "☿ $rev@$branch" $st
    fi
  fi
}

# Dir: current working directory (Muted indigo background, soft off-white text)
prompt_dir() {
  prompt_segment 060 253 "%~"
}

# Virtualenv (Dark slate background, pale teal text)
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment 238 109 "(%B$(basename "$virtualenv_path")%b)"
  fi
}

# Time: (Dark charcoal background, slate blue text)
prompt_time() {
  prompt_segment 236 103 "%D{%a %e %b - %H:%M}"
}

# Status: (Errors and indicators are muted to avoid glaring reds/yellows)
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%F{131}$CROSS "      # Soft rust for error
  [[ $UID -eq 0 ]] && symbols+="%F{136}$LIGHTNING "     # Muted gold for root
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%F{109}$GEAR " # Pale teal for jobs

  [[ -n "$symbols" ]] && prompt_segment 235 default "$symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  print -n "\n"
  prompt_status
  prompt_time
  prompt_virtualenv
  prompt_dir
  prompt_git
  prompt_hg
  prompt_end
  CURRENT_BG='NONE'
  print -n "\n"
  prompt_context
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '