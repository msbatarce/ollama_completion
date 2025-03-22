# Bash completion support for Ollama
# -----------------------------------------------------------------------------
#
# Author: Matias Batarce
# Date: 2025-03-22
#
# Installation:
# Just copy the file and source it in your `.bashrc` or `.zshrc`
#
# The script includes completions for `ollama pull` by querying
# `https://ollama.com/search` with `curl` and using a cache at
# `"${TMPDIR:-/tmp}/ollama_completion"`
#
# The behavior of this script can be customized by the use of the following
# environment variables:
#
# QUERY_OLLAMA_LIB_ENABLED
#   - Controls whether to complete against `ollama pull` and fetch models and
#   tags information. Set to `0` to disable.
#   Default: 1 (enabled)
#
# OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED
#   - Use [gum](https://github.com/charmbracelet/gum) to choose from the
#   available completions options interactively. Set to `0` to disable.
#   Default: 1 (enabled)
#
# OLLAMA_COMPLETION_CACHE_TTL_MINUTES
#   - Time To Live in minutes for the models and tags cache files invalidation.
#   Default: 10
#
# MIT License
# -----------------------------------------------------------------------------
# Copyright (c) 2025 [Matías Batarce]
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -----------------------------------------------------------------------------

if [[ ! $(which awk >/dev/null 2>&1 && echo $?) -eq 0 ]]; then
    echo "[$BASH_SOURCE]: awk required for ollama completion script"
    return
fi

function _setup_cache() {
    OLLAMA_COMPLETION_CACHE_DIR=${TMPDIR:-/tmp}/ollama_completion
    OLLAMA_COMPLETION_MODELS_CACHE=${OLLAMA_COMPLETION_CACHE_DIR}/models
    OLLAMA_COMPLETION_TAGS_CACHE_DIR=${OLLAMA_COMPLETION_CACHE_DIR}/tags
    mkdir -p $OLLAMA_COMPLETION_CACHE_DIR
    mkdir -p $OLLAMA_COMPLETION_TAGS_CACHE_DIR
    if [[ ! -f $OLLAMA_COMPLETION_MODELS_CACHE ]]; then
        touch -d "1 hours ago" $OLLAMA_COMPLETION_MODELS_CACHE
    fi
}

_setup_cache

function _setup_env() {
    if [[ -z "${OLLAMA_COMPLETION_CACHE_TTL_MINUTES}" ]]; then
        export OLLAMA_COMPLETION_CACHE_TTL_MINUTES=10
    fi
    if [[ -z "${OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED}" ]]; then
        export OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED=1
    fi
    if [[ ! $(which gum 1>/dev/null 2>&1 && echo $?) -eq 0 ]]; then
        OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED=0
    fi

    if [[ -z "${QUERY_OLLAMA_LIB_ENABLED}" ]]; then
        export QUERY_OLLAMA_LIB_ENABLED=1
    fi
    if [[ ! $(which xq >/dev/null 2>&1 && echo $?) -eq 0 ]]; then
        QUERY_OLLAMA_LIB_ENABLED=0
    fi
    if [[ ! $(which curl >/dev/null 2>&1 && echo $?) -eq 0 ]]; then
        QUERY_OLLAMA_LIB_ENABLED=0
    fi
}

_setup_env

_ollama_base_cmds() {
    ollama 2>&1 | awk '
        BEGIN { start = 0 }
        start == 1 && /^$/ {start = 0}
        start == 1 {print $1}
        /Available Commands/ { start = 1 }
    '
}

_query_ollama_lib() {
    q=$1
    if [[ -f "$OLLAMA_COMPLETION_MODELS_CACHE" ]] && \
        find "$OLLAMA_COMPLETION_MODELS_CACHE" -mmin "-${OLLAMA_COMPLETION_CACHE_TTL_MINUTES:-1}" | grep -q . ;
    then
        cat "$OLLAMA_COMPLETION_MODELS_CACHE" | grep "$q"
        return
    elif [[ -f "$OLLAMA_COMPLETION_MODELS_CACHE" ]]; then
        curl 2>/dev/null "https://ollama.com/search" | xq -q 'ul li h2' | tee "$OLLAMA_COMPLETION_MODELS_CACHE" | grep "$q"
        return
    fi
    curl 2>/dev/null "https://ollama.com/search?q=$q" | xq -q 'ul li h2'
}

_query_ollama_model_tags() {
    model=$1
    if [[ -f "$OLLAMA_COMPLETION_TAGS_CACHE_DIR/$model" ]] && \
        find "$OLLAMA_COMPLETION_TAGS_CACHE_DIR/$model" -mmin "-${OLLAMA_COMPLETION_CACHE_TTL_MINUTES:-1}" | grep -q . ;
    then
        cat "$OLLAMA_COMPLETION_TAGS_CACHE_DIR/$model"
        return
    elif [[ -d "$OLLAMA_COMPLETION_TAGS_CACHE_DIR" ]]; then
        curl 2>/dev/null "https://ollama.com/library/$model/tags" | xq -q 'section a' | tee "$OLLAMA_COMPLETION_TAGS_CACHE_DIR/$model"
        return
    fi
    curl 2>/dev/null "https://ollama.com/library/$model/tags" | xq -q 'section a'
}


_ollama_CMD_flags() {
  CMD=$1
    ollama $CMD -h 2>&1 | awk  '
        BEGIN { start = 0 }
        start == 1 && /^$/ {start = 0}
        start == 1 && !/,/ {
          print $1
        }
        start == 1 && /,/ {
            split($0, a, ",")
            gsub(/ /, "", a[1])
            print a[1]
            split(a[2], b, " ")
            print b[1]
        }
        /Flags:/ { start = 1 }
    '
}

_ollama_models() {
    ollama ls | tail -n +2 | cut -d' ' -f1
}

_ollama_ps() {
    ollama ps | tail -n +2 | cut -d' ' -f1
}

_use_gum_choose() {
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        return
    fi
    # Save cursor position
    printf '\033[s'
    # # Move the cursor down 1 line
    printf '\033[1B'
    TEMP=( $(gum choose --select-if-one "${COMPREPLY[@]}"))
    # Restore cursor position
    if [[ ${#TEMP[@]} -gt 0 ]]; then
        COMPREPLY=(${TEMP[@]})
        printf '\033[u'
    fi
}

_models_completion() {
    fn="$1"
    shift 1
    cmds=($@)
    MODEL=${cmds[2]}
    TAG=${cmds[4]}
    if [[ ${#cmds[@]} -eq 5  && "$CUR" = "" ]]; then
        return
    fi
    if [[ "${cmds[3]}" = : ]]; then
        COMPREPLY=( $(compgen -W "$($fn)" -- "${MODEL}:${TAG}"))
        COMPREPLY=("${COMPREPLY[@]#*:}")
        if [[ ${OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED} -eq 1 ]]; then
            _use_gum_choose
        fi
        return
    fi
    COMPREPLY=( $(compgen -W "$($fn)" -- "${CUR}"))
    if [[ ${OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED} -eq 1 ]]; then
        _use_gum_choose
    fi
}

_ollama_completion() {
    if [[ ${#COMP_WORDS[@]} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$(_ollama_base_cmds)" -- "${COMP_WORDS[1]}"))
        return
    fi

    CMD=${COMP_WORDS[1]}
    CUR=${COMP_WORDS[$COMP_CWORD]}
    if [[ "$CUR" =~ ^- ]]; then
      COMPREPLY=($(compgen -W "$(_ollama_CMD_flags $CMD)" -- "${CUR}"))
      return
    fi

    declare -a cmds=()
    for w in "${COMP_WORDS[@]}"; do
        if [[ ! "$w" =~ ^- ]]; then
            cmds+=($w)
        fi
    done

    case $CMD in
        run|rm|show|create|cp|push)
            _models_completion "_ollama_models" "${cmds[@]}"
            return
            ;;
        stop)
            _models_completion "_ollama_ps" "${cmds[@]}"
            return
            ;;
        help)
            COMPREPLY=( $(compgen -W "$(_ollama_base_cmds)" -- "${CUR}"))
            return
            ;;
        pull)
            if [[ $QUERY_OLLAMA_LIB_ENABLED = 0 ]]; then
                return
            fi
            MODEL=${cmds[2]}
            TAG=${cmds[4]}
            if [[ ${#cmds[@]} -eq 5  && "$CUR" = "" ]]; then
                return
            fi
            if [[ ${#cmds[@]} -eq 2 || ${#cmds[@]} -eq 3 ]]; then
                COMPREPLY=( $(compgen -W "$(_query_ollama_lib ${MODEL})" -- "${MODEL}"))
                if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
                    MODEL="${COMPREPLY[0]}"
                    COMPREPLY=( $(compgen -W "$(_query_ollama_model_tags ${MODEL})" -- "${TAG}"))
                    COMPREPLY=("${COMPREPLY[@]/#/"$MODEL":}")
                fi
            fi
            if [[ ${#cmds[@]} -gt 3 ]]; then
                COMPREPLY=( $(compgen -W "$(_query_ollama_model_tags ${MODEL})" -- "${TAG}"))
            fi
            if [[ ${OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED} -eq 1 ]]; then
                _use_gum_choose
            fi
            return
            ;;
        *)
            return
            ;;
    esac


}
complete -F _ollama_completion ollama
