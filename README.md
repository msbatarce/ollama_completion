# Ollama bash completions

## Installation

  Just copy the file and source it in your `.bashrc` or `.zshrc`.

   ```bash
   mkdir -p ~/.bash_completions.d
   wget -q -O - github.com/msbatarce/ollama_completion/raw/master/ollama_completion.bash >> ~/.bash_completions.d/ollama
   echo ". ~/.bash_completions.d/ollama" >> ~/.bashrc
  ```

## Description

The script includes completions for `ollama pull` by querying
[ollama.com](https://ollama.com/search) using `curl` and a cache at
`"${TMPDIR:-/tmp}/ollama_completion"`

The behavior of this script can be customized by the use of the following
environment variables:

`QUERY_OLLAMA_LIB_ENABLED`

- Controls whether to complete against `ollama pull` and fetch models and
  tags information.  
  Set to `0` to disable.  
  Default: 1 (enabled)

`OLLAMA_COMPLETION_GUM_CHOOSE_ENABLED`

- Use [gum](https://github.com/charmbracelet/gum) to choose from the
  available completions options interactively.  
  Set to `0` to disable.  
  Default: 1 (enabled)

`OLLAMA_COMPLETION_CACHE_TTL_MINUTES`

- Time To Live in minutes for the models and tags cache files invalidation.  
  Default: 10
