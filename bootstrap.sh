#!/usr/bin/env bash
#
# bootstrap.sh — deja una maquina nueva lista de cero: prerrequisitos, chezmoi,
# el repo, los paquetes y (opcional) shell por defecto y gestor de contrasenas.
#
# Uso:
#
#   curl -fsSL https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main/bootstrap.sh | bash
#
# Sobre tu propio fork, sin tocar el script:
#
#   DOTFILES_REPO=tu-usuario/dotfiles bash bootstrap.sh
#
# Prefiere SSH si tienes la clave dada de alta en GitHub; si no, usa HTTPS.
# Es idempotente: se puede re-ejecutar sin romper nada.

set -euo pipefail

# Cambialo aqui si haces fork, o pasa DOTFILES_REPO por entorno.
REPO_SLUG="${DOTFILES_REPO:-MiguelAguiarDEV/dotfiles}"
REPO_SSH="git@github.com:${REPO_SLUG}.git"
REPO_HTTPS="https://github.com/${REPO_SLUG}.git"
BIN="$HOME/.local/bin"

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  B=$(tput bold); D=$(tput dim); R=$(tput sgr0)
  G=$(tput setaf 2); Y=$(tput setaf 3); C=$(tput setaf 4)
else
  B=""; D=""; R=""; G=""; Y=""; C=""
fi
say()  { printf '\n%s%s▸ %s%s\n' "$B" "$C" "$1" "$R"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$R" "$1"; }
note() { printf '  %s%s%s\n' "$D" "$1" "$R"; }
warn() { printf '  %s⚠ %s%s\n' "$Y" "$1" "$R"; }
have() { command -v "$1" >/dev/null 2>&1; }
ask()  { local r; printf '  %s? %s [y/N]%s ' "$Y" "$1" "$R"; read -r r </dev/tty || true; [[ "$r" =~ ^[Yy] ]]; }

mkdir -p "$BIN"
export PATH="$BIN:$PATH"

# ==========================================================================
say "1/5 · Prerrequisitos"
# ==========================================================================
MISSING=()
for c in curl git; do have "$c" || MISSING+=("$c"); done
if (( ${#MISSING[@]} )); then
  note "faltan: ${MISSING[*]}"
  if   have pacman;  then sudo pacman -S --needed --noconfirm "${MISSING[@]}"
  elif have apt-get; then sudo apt-get -o DPkg::Lock::Timeout=600 update -qq \
       && sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=600 install -y -q "${MISSING[@]}"
  else warn "instala ${MISSING[*]} a mano y vuelve a ejecutar"; exit 1; fi
fi
ok "curl y git disponibles"

# ==========================================================================
say "2/5 · chezmoi"
# ==========================================================================
if have chezmoi; then
  ok "ya instalado: $(chezmoi --version | head -1)"
else
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN" >/dev/null
  ok "instalado en $BIN/chezmoi"
fi
CHEZMOI="$(command -v chezmoi || echo "$BIN/chezmoi")"

# ==========================================================================
say "3/5 · Repo de dotfiles"
# ==========================================================================
# Se elige el transporte que realmente funcione, en vez de asumir uno.
REPO=""
# ConnectTimeout: sin red, ssh se quedaria colgado y el bootstrap con el.
if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
       -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
  REPO="$REPO_SSH"; note "usando SSH"
elif have gh && gh auth status >/dev/null 2>&1; then
  REPO="$REPO_HTTPS"; note "usando HTTPS con las credenciales de gh"
  git config --global --get-all credential."https://github.com".helper 2>/dev/null | grep -q 'gh auth' \
    || git config --global --add credential."https://github.com".helper '!gh auth git-credential'
else
  REPO="$REPO_HTTPS"; note "usando HTTPS anonimo"
  note "si el repo fuera privado, autentica antes con: gh auth login"
fi

if [[ -d "$($CHEZMOI source-path 2>/dev/null || echo /nonexistent)/.git" ]]; then
  ok "el repo ya esta clonado en $($CHEZMOI source-path)"
  note "actualizando y aplicando…"
  "$CHEZMOI" update --force
else
  note "clonando y aplicando (esto instala tambien los paquetes)…"
  "$CHEZMOI" init --apply --promptDefaults "$REPO"
fi
ok "dotfiles aplicados"

# ==========================================================================
say "4/5 · Shell por defecto"
# ==========================================================================
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
ZSH_PATH="$(command -v zsh || true)"
if [[ -z "$ZSH_PATH" ]]; then
  warn "zsh no esta instalado; se queda $CURRENT_SHELL"
elif [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
  ok "ya es zsh"
else
  note "shell actual: $CURRENT_SHELL"
  # Se prueba zsh ANTES de cambiar: un rc roto con la shell ya cambiada deja
  # la cuenta sin poder entrar.
  #
  # `exit 0` explicito, no `exit` a secas: sin argumento devuelve el estado del
  # ultimo comando, y sin TTY el rc deja un aviso benigno del zle que lo pondria
  # a 1. Lo que se comprueba es que el rc no reviente, no ese aviso: por eso se
  # filtran ademas los errores reales del stderr.
  zsh_err="$(zsh -i -c 'exit 0' </dev/null 2>&1 >/dev/null || true)"
  zsh_bad="$(printf '%s' "$zsh_err" | grep -viE "can't change option: zle|no such file or directory: /dev/tty" || true)"
  if zsh -i -c 'exit 0' </dev/null >/dev/null 2>&1 && [[ -z "$zsh_bad" ]]; then
    ok "zsh arranca sin errores con esta config"
    if ask "¿Poner zsh como shell por defecto?"; then
      grep -qx "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
      sudo chsh -s "$ZSH_PATH" "$USER" && ok "cambiada a $ZSH_PATH"
    else
      note "sin cambios; para hacerlo luego: sudo chsh -s $ZSH_PATH $USER"
    fi
  else
    warn "zsh no arranca limpio con esta config; NO se cambia la shell"
    [[ -n "$zsh_bad" ]] && printf '%s\n' "$zsh_bad" | head -3 | sed 's/^/      /'
  fi
fi

# ==========================================================================
say "5/5 · Gestor de contrasenas (opcional)"
# ==========================================================================
if [[ -x "$BIN/secrets-setup" ]]; then
  if ask "¿Lanzar secrets-setup ahora?"; then
    "$BIN/secrets-setup"
  else
    note "cuando quieras: secrets-setup"
  fi
else
  warn "secrets-setup no encontrado en $BIN"
fi

# ==========================================================================
printf '\n%s%s  ✓ Listo%s\n\n' "$B" "$G" "$R"
note "Comprobacion rapida:"
for c in starship zsh eza bat fd rg fzf zoxide direnv delta nvim lazygit; do
  if have "$c"; then printf '    %s✓%s %s\n' "$G" "$R" "$c"
  else               printf '    %s·%s %s (no instalado)\n' "$D" "$R" "$c"; fi
done
printf '\n'
note "Abre una terminal nueva para ver el prompt."
