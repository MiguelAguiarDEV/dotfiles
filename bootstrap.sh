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

# ¿Hay alguien delante? Sin terminal no se puede preguntar nada, y el wizard se
# salta entero en favor de los valores por defecto.
interactive() { [[ -r /dev/tty && -t 0 ]] || [[ -r /dev/tty && -t 1 ]]; }

# field VAR "Etiqueta" "valor por defecto" — texto libre; Enter acepta el default.
field() {
  local var="$1" label="$2" def="${3:-}" in=""
  if [[ -n "$def" ]]; then printf '  %s%-22s%s %s[%s]%s ' "$B" "$label" "$R" "$D" "$def" "$R"
  else                     printf '  %s%-22s%s ' "$B" "$label" "$R"; fi
  read -r in </dev/tty || true
  printf -v "$var" '%s' "${in:-$def}"
}

# yesno VAR "Etiqueta" default(true|false) — Enter acepta el default.
yesno() {
  local var="$1" label="$2" def="$3" in="" hint
  [[ "$def" == true ]] && hint="S/n" || hint="s/N"
  printf '  %s%-22s%s %s[%s]%s ' "$B" "$label" "$R" "$D" "$hint" "$R"
  read -r in </dev/tty || true
  case "$in" in
    [SsYy]*) printf -v "$var" 'true'  ;;
    [Nn]*)   printf -v "$var" 'false' ;;
    *)       printf -v "$var" '%s' "$def" ;;
  esac
}

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
say "3/6 · Tus datos"
# ==========================================================================
# Defaults: lo que ya tengas configurado en la maquina.
DEF_NAME="$(git config --global --get user.name  2>/dev/null || true)"
DEF_EMAIL="$(git config --global --get user.email 2>/dev/null || true)"
DEF_GH="$(gh api user --jq .login 2>/dev/null || true)"
DEF_EDITOR="vim"
for e in nvim vim micro nano; do have "$e" && { DEF_EDITOR="$e"; break; }; done

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
RECONFIG=1
if [[ -f "$CFG" ]]; then
  # Ya se respondio antes. `promptStringOnce` no volveria a preguntar y
  # `chezmoi update` ni siquiera regenera el config, asi que preguntar aqui
  # seria enganoso: se ofrece rehacerlo de forma explicita.
  note "ya hay una configuracion en $CFG"
  grep -E '^\s+(name|email|github_user|editor)' "$CFG" 2>/dev/null | sed 's/^/    /'
  if ask "¿Volver a rellenar tus datos?"; then rm -f "$CFG"; else RECONFIG=0; fi
fi

if (( RECONFIG )) && interactive; then
  note "Enter acepta el valor entre corchetes. Se pregunta una sola vez:"
  note "queda guardado en ~/.config/chezmoi/chezmoi.toml."
  printf '\n  %s%sIdentidad%s %s(va a tu ~/.gitconfig)%s\n' "$B" "$C" "$R" "$D" "$R"
  field W_NAME  "Nombre"             "$DEF_NAME"
  field W_EMAIL "Email"              "$DEF_EMAIL"
  field W_GH    "Usuario de GitHub"  "$DEF_GH"

  printf '\n  %s%sPreferencias%s\n' "$B" "$C" "$R"
  field W_EDITOR "Editor"            "$DEF_EDITOR"
  field W_BRANCH "Rama por defecto"  "main"
  yesno W_REBASE "git pull --rebase" false

  printf '\n  %s%sQue instalar%s\n' "$B" "$C" "$R"
  yesno W_DOCKER "Docker"                  true
  yesno W_K8S    "Aliases de Kubernetes"   false
  yesno W_AI     "Aliases de agentes IA"   false
  printf '\n'
elif (( RECONFIG )); then
  note "sin terminal interactiva: se usan los valores por defecto"
  W_NAME="$DEF_NAME"; W_EMAIL="$DEF_EMAIL"; W_GH="$DEF_GH"
  W_EDITOR="$DEF_EDITOR"; W_BRANCH="main"; W_REBASE=false
  W_DOCKER=true; W_K8S=false; W_AI=false
else
  note "se conservan los datos ya guardados"
fi

# Estos valores alimentan las plantillas del repo; chezmoi los guarda y no
# vuelve a preguntar en los siguientes `apply`.
PROMPTS=()
(( RECONFIG )) && PROMPTS=(
  --promptString "name=$W_NAME"
  --promptString "email=$W_EMAIL"
  --promptString "github_user=$W_GH"
  --promptString "editor=$W_EDITOR"
  --promptString "git_branch=$W_BRANCH"
  --promptBool   "git_rebase=$W_REBASE"
  --promptBool   "docker=$W_DOCKER"
  --promptBool   "k8s=$W_K8S"
  --promptBool   "ai=$W_AI"
)

# ==========================================================================
say "4/6 · Repo de dotfiles"
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
  # `chezmoi update` no regenera el config: si se han vuelto a pedir los datos,
  # hay que pasar por `init` antes.
  (( ${#PROMPTS[@]} )) && "$CHEZMOI" init "${PROMPTS[@]}"
  note "actualizando y aplicando…"
  "$CHEZMOI" update --force
else
  note "clonando y aplicando (esto instala tambien los paquetes)…"
  "$CHEZMOI" init --apply ${PROMPTS[@]+"${PROMPTS[@]}"} "$REPO"
fi
ok "dotfiles aplicados"

# ==========================================================================
say "5/6 · Shell por defecto"
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
say "6/6 · Gestor de contrasenas (opcional)"
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
