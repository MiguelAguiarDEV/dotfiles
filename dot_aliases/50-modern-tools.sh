# Modern CLI replacements (sólo si están instalados, no rompen si falta alguno)

# eza -> reemplazo de ls
# --icons=auto: dibuja iconos solo cuando la salida va a un terminal, nunca al
# redirigir a un fichero o a otro comando. Necesita una Nerd Font en el emulador
# (se renderiza en el cliente, no aqui); sin ella salen cuadrados.
if command -v eza >/dev/null 2>&1; then
  # `ls` tambien pasa por eza. Acepta -l -a -h -1 -R -S -t -F, asi que el uso
  # habitual no cambia. Para el ls de coreutils de verdad: `command ls` o `\ls`.
  alias ls='eza --icons=auto --group-directories-first'
  alias l='eza -a1 --icons=auto --group-directories-first --show-symlinks'
  alias ll='eza -la --icons=auto --git --group-directories-first --time-style=long-iso'
  alias la='eza -a --icons=auto --group-directories-first'
  alias lt='eza --tree --icons=auto --level=2 --git-ignore'
  alias lT='eza --tree --icons=auto --git-ignore'
fi

# bat -> cat con sintaxis (sin override de cat, alias dedicado)
command -v bat >/dev/null 2>&1 && alias bcat='bat --paging=never --style=plain'

# TUIs
command -v lazygit    >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias ldock='lazydocker'

# httpie con pretty
command -v http >/dev/null 2>&1 && alias http='http --pretty=all'

# Notas:
# - 'z <dir>' viene de zoxide (init en .zshrc): salto por frecuencia
# - 'rg'    = ripgrep   |  'fd' = fd-find  |  'yq' = YAML jq
# - 'tldr <cmd>' = páginas concisas con ejemplos
# - 'direnv' carga .envrc por directorio (allowlist con 'direnv allow')
