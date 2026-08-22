# General shortcuts (POSIX: los cargan bash y zsh via ~/.shell_common.sh)
alias ll='ls -lhAF'
alias la='ls -A'   # 50-modern-tools lo sustituye por eza si está instalado
alias l='ls -C'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec "$SHELL"'   # shell nuevo → relee el rc que toque (bash o zsh)
alias h='history'
