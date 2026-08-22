# ~/.aliases/

Cada archivo `*.sh` se carga automáticamente desde `~/.shell_common.sh`
(que a su vez cargan `~/.bashrc` y `~/.zshrc`), así que **todo debe ser
POSIX**: nada de globs `(N)`, arrays zsh ni bashisms.

Prefijo numérico controla el orden de carga (00 -> 99).
Añade un archivo nuevo y recarga con `reload` (abre un shell nuevo).
