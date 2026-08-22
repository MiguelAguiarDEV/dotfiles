# Puentes con Windows. Con appendWindowsPath=false estos .exe salen del PATH,
# asi que se reponen como aliases.
#
# OJO con los globs: zsh aborta el fichero entero con "no matches found" si un
# patron no encuentra nada (bash lo deja tal cual y sigue). Por eso el unico
# glob va dentro de un `if [ -d ... ]`, y nunca se expande fuera de WSL.

if [ -d /mnt/c/Users ]; then
  # VS Code: instalacion por usuario (la habitual)
  for _home in /mnt/c/Users/*/; do
    _p="${_home}AppData/Local/Programs/Microsoft VS Code/bin/code"
    if [ -x "$_p" ]; then alias code="\"$_p\""; break; fi
  done
  unset _home _p
  # …o global
  if ! alias code >/dev/null 2>&1 && [ -x "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]; then
    alias code='"/mnt/c/Program Files/Microsoft VS Code/bin/code"'
  fi

  [ -x /mnt/c/Windows/explorer.exe ] && alias explorer='/mnt/c/Windows/explorer.exe'
  [ -x /mnt/c/Windows/System32/clip.exe ] && alias wclip='/mnt/c/Windows/System32/clip.exe'
fi
