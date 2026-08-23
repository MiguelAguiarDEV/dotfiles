# dotfiles

Configuración de terminal para Linux, WSL y VPS, gestionada con
[chezmoi](https://chezmoi.io). Una máquina nueva queda lista con un comando.

**Alcance: solo terminal.** Nada de escritorio — ni compositor, ni barra, ni
lanzador, ni emulador de terminal, ni tema gráfico. Por eso se aplica igual en
una workstation, en WSL y en un servidor sin pantalla.

```
zsh + starship          prompt idéntico en bash y zsh, sin gestor de plugins
eza bat fd rg fzf …     reemplazos modernos de las herramientas de siempre
neovim                  lazy.nvim, 12 plugins, LSP
chezmoi                 plantillas por máquina, sin condicionales por hostname
```

Arranque medido: **295 ms** en zsh, **133 ms** en bash.

## Desde Windows: instalar WSL y todo lo demás

Un solo script deja un Windows recién instalado con WSL2, Ubuntu y estos
dotfiles. **En PowerShell como administrador:**

```powershell
irm https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main/bootstrap-wsl.ps1 | iex
```

| Paso | Qué hace |
|---|---|
| 1 · **Asistente** | Pregunta distro, recursos de WSL, red y qué tocar en Windows |
| 2 · WSL2 | Habilita las features de Windows y actualiza el kernel |
| 3 · `.wslconfig` | Escribe lo que respondiste; si el fichero ya existe, no lo toca |
| 4 · Ubuntu | La instala y crea tu usuario con contraseña y `sudo`, sin el asistente interactivo |
| 5 · Fuente | JetBrainsMono Nerd Font en tu perfil (sin permisos de máquina) |
| 6 · Terminal | Fuente, tema oscuro, y el perfil de WSL por defecto arrancando en `~` |
| 7 · Dotfiles | Lanza `bootstrap.sh` dentro de WSL, con **su** asistente |

Son dos asistentes porque cada uno pregunta lo suyo: el de Windows cubre la
máquina virtual, y el de Linux tu identidad de git, editor y lenguajes.

```
  Sistema
  Distribucion             [Ubuntu-24.04]

  Recursos de WSL
  Detectado: 31GB de RAM, 12 CPUs
  Memoria (GB)             [15]
  CPUs                     [12]
  Swap (GB)                [4]

  Red
  Modo espejo              [S/n]

  Windows
  Instalar Nerd Font       [S/n]
  Configurar Terminal      [S/n]
```

Si ya tenías un `.wslconfig`, el asistente **te enseña lo que hay dentro** y da
a elegir:

| | |
|---|---|
| **1** | Conservarlo tal cual |
| **2** | Actualizar solo esas claves, **respetando tus comentarios** (por defecto) |
| **3** | Reemplazarlo entero por el de referencia |

Con la opción 2 los valores que ya tuvieras pasan a ser la propuesta por
defecto, así que puedes cambiarlos o dejarlos con Enter. Siempre guarda una
copia antes de escribir.

El modo espejo comparte el loopback con Windows, pero rompe algunas VPN
corporativas: si respondes que no, se deja la red en NAT.

Es idempotente y detecta lo que ya está hecho. Si Windows aún no tenía WSL hará
falta **un reinicio**: el script lo dice y, al volver a ejecutarlo, continúa por
donde iba.

Sobre una máquina que ya estaba en marcha no duplica nada: si ya tienes una
Ubuntu registrada la reutiliza en vez de instalar otra, y si esa distro ya tiene
un usuario normal usa ese en lugar de crear uno nuevo. Solo pregunta el nombre
de usuario cuando la distro está recién instalada, proponiendo el de Windows
saneado a un nombre válido en Linux.

```powershell
# opciones
.\bootstrap-wsl.ps1 -User miguel -Distro Ubuntu-24.04 -SkipTerminal
```

## Probar sin instalar nada

```bash
docker run -it --rm ubuntu:24.04 bash -c \
  'apt-get update -qq && apt-get install -y -q curl sudo git >/dev/null && \
   curl -fsSL https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main/bootstrap.sh | bash'
```

Contenedor de usar y tirar: tu sistema no se toca.

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main/bootstrap.sh | bash
```

Sobre tu propio fork, sin editar nada:

```bash
DOTFILES_REPO=tu-usuario/dotfiles bash bootstrap.sh
```

`bootstrap.sh` hace seis cosas, y es idempotente:

| Paso | Qué hace |
|---|---|
| 1 · Prerrequisitos | Instala `curl` y `git` si faltan (pacman o apt) |
| 2 · chezmoi | Lo descarga a `~/.local/bin` si no está |
| 3 · **Tus datos** | Un asistente pregunta lo que hay que personalizar (abajo) |
| 4 · Repo | Prueba SSH primero, cae a HTTPS. `chezmoi init --apply`, que dispara la instalación de paquetes |
| 5 · Shell | **Comprueba que zsh arranca limpio antes** de ofrecer `chsh`. Con un rc roto y la shell ya cambiada te quedas fuera de la cuenta |
| 6 · Secretos | Ofrece lanzar `secrets-setup` (opcional) |

### El asistente

Se responde **una sola vez**: queda guardado en
`~/.config/chezmoi/chezmoi.toml` y los siguientes `chezmoi apply` no vuelven a
preguntar. Cada campo propone un valor por defecto sacado de tu máquina, y
Enter lo acepta.

| | Campo | Por defecto | Dónde acaba |
|---|---|---|---|
| **Identidad** | Nombre | tu `git config user.name` | `~/.gitconfig` |
| | Email | tu `git config user.email` | `~/.gitconfig` |
| | Usuario de GitHub | `gh api user` si estás autenticado | disponible en las plantillas |
| **Preferencias** | Editor | el primero de nvim/vim/micro/nano que tengas | `$EDITOR`, `$VISUAL`, `git core.editor` |
| | Rama por defecto | `main` | `git init.defaultBranch` |
| | `git pull --rebase` | no | `git pull.rebase` |
| **Lenguajes** | Go · Rust · Node · Python | sí los cuatro | instalados bajo `$HOME`, sin `sudo` |
| **Qué más** | Docker | sí | filtra los paquetes de docker de las listas |
| | Aliases de Kubernetes | no | despliega o no `~/.aliases/30-kubectl.sh` |
| | Aliases de agentes IA | no | despliega o no `~/.aliases/60-ai.sh` |

Al re-ejecutar el bootstrap detecta que ya respondiste, te enseña lo guardado y
ofrece rehacerlo. Sin terminal interactiva (CI, provisioning desatendido) toma
todos los valores por defecto sin preguntar.

A mano, si prefieres:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
chezmoi init --apply https://github.com/MiguelAguiarDEV/dotfiles.git
```

## Hacerlo tuyo

Haz fork y toca estos cuatro sitios; el resto funciona solo:

| Quiero cambiar | Fichero |
|---|---|
| Qué se instala | `packages/apt.txt` (Debian/Ubuntu) · `packages/repo.txt` (Arch) |
| Los aliases | `dot_aliases/*.sh` — un fichero por tema, se cargan todos |
| El prompt | `dot_config/starship.toml` |
| Neovim | `dot_config/nvim/` |

Lo que valga para una sola máquina va en `~/.bashrc.local` o `~/.zshrc.local`,
que se cargan al final de cada rc y **no** se versionan.

## Qué instala

Dos listas de paquetes, según la distro. Ambas son de **intención**, no volcados
del gestor de paquetes:

| Fichero | Para | Paquetes |
|---|---|---|
| `packages/apt.txt` | Debian / Ubuntu / VPS | 44 |
| `packages/repo.txt` | Arch / CachyOS (`pacman`) | 56 |
| `packages/aur.txt` | Arch, vía `paru`/`yay` | 2 |

`run_onchange_before_install-packages.sh.tmpl` detecta el gestor y usa la que
toque. Además instala lo que no está empaquetado, en `~/.local/bin` y sin
`sudo`:

| Herramienta | Por qué a mano |
|---|---|
| **starship** | No está en apt |
| **neovim** | Ubuntu 24.04 trae 0.9.5 y la config necesita 0.11+; se baja el tarball oficial |
| **eza** | No está en Debian ni Ubuntu; se añade el repo del proyecto |
| **lazygit**, **lazydocker** | Solo publican binarios en GitHub |

### Lenguajes

Los cuatro se instalan bajo `$HOME`, sin `sudo`, y cada uno se puede desmarcar
en el asistente:

| | Cómo | Por qué así |
|---|---|---|
| **Go** | tarball oficial → `~/.local/share/go-dist` | Ubuntu 24.04 trae 1.22; la oficial va por 1.27. Solo se instala si el sistema no tiene ya 1.25 o superior |
| **Rust** | `rustup` → `~/.cargo` | Con `--no-modify-path`: del `PATH` se encarga `~/.shell_common.sh`, así rustup no toca tus rc |
| **Node** | `nvm` + LTS → `~/.nvm` | Para cambiar de versión por proyecto. `nvm` se carga de forma diferida, así que no cuesta nada al arrancar |
| **Python** | el de la distro + **`uv`** | `python3` ya viene en todas; lo que falta es un gestor moderno |

Y resuelve dos cosas más de Debian: los enlaces `bat`→`batcat` y `fd`→`fdfind`
(Debian los renombra), y el locale UTF-8 sin el cual los iconos de eza y
starship salen como `?`.

## Clasificación de máquina

`.chezmoi.toml.tmpl` guarda diez variables, todas resueltas en `chezmoi init`:
las nueve del asistente más `wsl`, que se autodetecta (kernel `microsoft`) y
excluye los puentes con Windows en el resto de máquinas.

No hay condicionales por hostname: solo importa la **clase** de máquina. Lo que
depende de una herramienta va con guarda de existencia (`[ -d … ]` en shell,
`lookPath` en plantillas Go), y lo que aplica a un solo host va en
`~/.bashrc.local` / `~/.zshrc.local`, que no se versionan.

Sin `bootstrap.sh`, `chezmoi init` hace las mismas preguntas en texto plano.
Para responder sin interacción:

```bash
chezmoi init --apply --promptDefaults https://github.com/MiguelAguiarDEV/dotfiles.git
```

O fijando valores concretos, que es lo que hace `bootstrap.sh` por dentro:

```bash
DOTFILES_NAME="Tu Nombre" DOTFILES_EMAIL=tu@correo.com DOTFILES_K8S=true \
  chezmoi init --apply --promptDefaults \
  https://github.com/MiguelAguiarDEV/dotfiles.git
```

Las variables son `DOTFILES_` + `NAME`, `EMAIL`, `GH`, `EDITOR`, `BRANCH`,
`REBASE`, `GO`, `RUST`, `NODE`, `PYTHON`, `DOCKER`, `K8S`, `AI`. Los booleanos
aceptan `true` o `false`.

## Secrets

**El repo no integra ningún gestor de contraseñas.** No hay referencias `op://`,
ni plantillas que lean de una bóveda, ni preguntas en `chezmoi init`.

Queda un solo gancho, en `~/.shell_common.sh`: si existe `~/.secrets/`, se
cargan todos sus `*.sh`. Esos ficheros se escriben a mano (`export VAR=...`,
POSIX puro) y nunca se versionan — `.gitignore` los excluye.

Para instalar y autenticar un gestor hay un asistente aparte: **`secrets-setup`**,
que se despliega en `~/.local/bin/`. Es un script independiente — no lo llama
`chezmoi apply` ni condiciona el resto del repo.

Su objetivo es **autenticarse una vez y no volver a hacerlo**:

| Gestor | Cómo evita re-autenticar |
|---|---|
| `1password` | Service account: un token de solo lectura que **no caduca**. Es el único pensado para máquinas sin nadie delante. |
| `bitwarden` | API key (evita el login) + contraseña maestra guardada, y un wrapper de `bw` que desbloquea **la primera vez que lo usas en cada shell**, no al arrancar. |
| `pass` | GPG: no hay sesión que expire. El asistente sube además la caché del agente a 8 h. |

El desbloqueo automático de Bitwarden guarda la contraseña maestra en
`~/.secrets/10-bitwarden.sh` (permisos `600`, fuera del repo). El asistente lo
avisa y deja declinar: entonces guarda solo la API key y el desbloqueo sigue
siendo manual.

Detecta el gestor de paquetes (`pacman` / `apt`), instala el CLI, guía el alta
de credenciales y verifica que lee **sin pedir nada**. Todo lo que escribe va a
`~/.secrets/` — nunca al repo.

```bash
secrets-setup
```

**Por qué no hay ninguna variable de API por defecto:** exportar
`GITHUB_TOKEN` hace que `gh` la prefiera sobre su propia sesión OAuth y cambia
en silencio la credencial que usan `gh` y `git`; y exportar `ANTHROPIC_API_KEY`
puede hacer que Claude Code facture por API en vez de consumir una suscripción.
Si las necesitas, añádelas tú a `~/.secrets/` sabiendo eso.

## Contenido gestionado

| Ruta destino | Origen | Notas |
|---|---|---|
| `~/.shell_common.sh` | `dot_shell_common.sh` | PATH, nvm, editor, aliases y secrets — compartido bash/zsh, POSIX puro |
| `~/.zshrc` | `dot_zshrc` | Historial, completions, 2 plugins por `source` directo (sin gestor); carga `shell_common` |
| `~/.config/starship.toml` | `dot_config/starship.toml` | Prompt — la misma config en bash y en zsh |
| `~/.bashrc` | `dot_bashrc` | Mínimo: historial, completions, `shell_common`, starship |
| `~/.aliases/*.sh` | `dot_aliases/` | Aliases por tema (git, docker, kubectl, IA, puentes WSL), POSIX |
| `~/.gitconfig` | `dot_gitconfig.tmpl` | `delta` solo si está instalado |
| `~/.config/git/ignore` | `dot_config/git/ignore` | gitignore global |
| `~/.config/nvim/` | `dot_config/nvim/` | Neovim: lazy.nvim, 12 plugins, LSP |
| `~/.local/bin/win-temp-path` | `dot_local/bin/` | Resuelve la ruta WSL del `%TEMP%` de Windows — solo WSL |
| `~/.local/bin/secrets-setup` | `dot_local/bin/` | Asistente de gestores de contraseñas |
| `packages/*.txt` · `bootstrap.sh` | — | Solo viven en el repo, no se despliegan |

## Shell y prompt

Sin gestor de plugins: `~/.zshrc` hace dos `source` directos
(`zsh-autosuggestions` y `zsh-syntax-highlighting`, este último el último de
todo porque envuelve los widgets ya definidos). Busca cada plugin en la ruta de
Arch, la de Debian/Ubuntu y `~/.zsh/`, en ese orden.

Las completions de `kubectl`, `helm`, `docker` y `gh` se generan **una vez** en
`~/.zsh/completions` en lugar de con un `eval` en cada arranque. Para
regenerarlas, borra el fichero correspondiente.

El prompt es [starship](https://starship.rs): un binario sin dependencias y una
sola config (`~/.config/starship.toml`) que vale igual para bash y para zsh.
`hostname` está en `ssh_only = true` y en rojo, así que solo aparece cuando
estás en una máquina remota. Si starship no está instalado, `~/.bashrc` cae a un
`PS1` básico y `~/.zshrc` al prompt por defecto de zsh.

## Velocidad de arranque

El rc esta ordenado para que nada caro corra antes de tiempo. Tres cosas, todas
medidas en la WSL de referencia:

| | Antes | Despues |
|---|---|---|
| zsh | 1385 ms | **295 ms** |
| bash | 671 ms | **133 ms** |

1. **nvm no se carga en el arranque.** `nvm.sh` costaba ~400 ms. Ahora se mete
   en el PATH la version por defecto y `nvm` es una funcion que carga el script
   de verdad la primera vez que se la llama. `node`, `npm`, `npx` y los globales
   de esa version (pnpm, yarn) siguen disponibles desde el primer prompt.
2. **El PATH de Windows se poda en WSL.** WSL inyecta ~29 rutas de `/mnt/c`;
   cada busqueda fallida las recorre todas sobre DrvFs. Medido: 10 `command -v`
   de comandos inexistentes pasan de 5 ms a 761 ms. `/etc/wsl.conf` pone
   `appendWindowsPath=false` y `shell_common.sh` deja solo `System32` y la ruta
   de `powershell.exe`. Los `.exe` que se pierden vuelven como aliases en
   `~/.aliases/70-wsl.sh`.
3. **`shell_common.sh` se carga lo primero en `~/.zshrc`**, antes que el bucle
   de completions: si no, ese bucle corre con el PATH sin podar y cuesta 245 ms.

## Comandos habituales

| Acción | Comando |
|---|---|
| Ver qué cambiaría | `chezmoi diff` |
| Aplicar cambios pendientes | `chezmoi apply` |
| Editar archivo (abre source) | `chezmoi edit ~/.zshrc` |
| Añadir archivo nuevo | `chezmoi add ~/.config/foo/bar.conf` |
| Añadir un paquete | Editar `packages/repo.txt` a mano — es una lista de intención, no un volcado de `pacman -Qen` |
| Commit y push | `chezmoi cd` → `git add -A && git commit -m "..." && git push` |

## Exclusiones

Ver `.chezmoiignore` (es una plantilla: usa `wsl`). Solo lista
rutas que existen en el source — chezmoi jamás toca ficheros que no gestiona,
así que caches, historiales o `~/.claude` no necesitan exclusión: simplemente
no están en el repo.

Nada de Claude Code se versiona aquí: ni `settings.json`, ni skills, ni
statusline, ni configuración de MCP. Sus memorias y sesiones viven en su propio
sitio y se respaldan aparte.

## Ajustes por máquina

| Caso | Dónde va |
|---|---|
| Variable de entorno o alias de un solo host | `~/.bashrc.local` / `~/.zshrc.local` (no versionados, se cargan al final) |
| Config de la empresa (EKS, AWS…) | `~/.zshrc.local` de la máquina de trabajo, nunca el repo |
| Config que depende de una herramienta instalada | Bloque guardado con `[ -d … ]` / `[ -x … ]` en shell, o `{{ if lookPath "…" }}` en una plantilla |
| Config que depende de la clase de máquina | `wsl` en `.chezmoiignore` o plantillas |
| Secrets | `~/.secrets/*.sh` escritos a mano; el gestor se instala aparte con `secrets-setup` |
