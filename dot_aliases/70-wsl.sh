# Puentes con Windows. Con appendWindowsPath=false estos .exe salen del PATH,
# asi que se reponen como aliases. Todo va con guarda de existencia: en Linux
# nativo no hay /mnt/c y este fichero no define nada.

# VS Code: instalacion por usuario (la habitual) o global
for _p in /mnt/c/Users/*/AppData/Local/Programs/"Microsoft VS Code"/bin/code \
          "/mnt/c/Program Files/Microsoft VS Code/bin/code"; do
  if [ -x "$_p" ]; then alias code="\"$_p\""; break; fi
done
unset _p

[ -x /mnt/c/Windows/explorer.exe ] && alias explorer='/mnt/c/Windows/explorer.exe'
[ -x /mnt/c/Windows/System32/clip.exe ] && alias wclip='/mnt/c/Windows/System32/clip.exe'
