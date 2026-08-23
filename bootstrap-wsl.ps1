<#
.SYNOPSIS
  Deja un Windows recien instalado con WSL2 + Ubuntu + estos dotfiles.

.DESCRIPTION
  Hace de una sentada lo que si no son veinte minutos de clics:

    1. Habilita WSL2 y la plataforma de maquina virtual
    2. Escribe %USERPROFILE%\.wslconfig
    3. Instala Ubuntu y crea tu usuario con contrasena y sudo
    4. Instala JetBrainsMono Nerd Font
    5. Configura Windows Terminal: fuente, tema oscuro y WSL por defecto
    6. Ejecuta bootstrap.sh dentro de WSL, que aplica los dotfiles

  Es idempotente: cada paso comprueba si ya esta hecho. Si Windows aun no
  tenia WSL hara falta un reinicio; el script lo detecta, lo dice, y al
  volver a ejecutarlo continua por donde iba.

.PARAMETER User
  Usuario de Linux a crear. Por defecto, tu nombre de usuario de Windows en
  minusculas.

.PARAMETER Distro
  Distribucion a instalar. Por defecto Ubuntu-24.04.

.PARAMETER SkipTerminal
  No tocar la configuracion de Windows Terminal.

.EXAMPLE
  # Desde PowerShell COMO ADMINISTRADOR:
  irm https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main/bootstrap-wsl.ps1 | iex

.EXAMPLE
  # Con un usuario concreto, habiendo descargado el fichero:
  .\bootstrap-wsl.ps1 -User miguel
#>
[CmdletBinding()]
param(
    [string]$User,
    [string]$Distro = 'Ubuntu-24.04',
    [switch]$SkipTerminal
)

$ErrorActionPreference = 'Stop'
$RepoRaw = 'https://raw.githubusercontent.com/MiguelAguiarDEV/dotfiles/main'

# ---------------------------------------------------------------- presentacion
function Say  ($m) { Write-Host "`n▸ $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "  ✓ $m"  -ForegroundColor Green }
function Note ($m) { Write-Host "  $m"    -ForegroundColor DarkGray }
function Warn ($m) { Write-Host "  ⚠ $m"  -ForegroundColor Yellow }
function Die  ($m) { Write-Host "`n  ✗ $m`n" -ForegroundColor Red; exit 1 }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# wsl.exe emite SU propia salida (--list, --status) en UTF-16LE, pero la de los
# comandos que ejecuta dentro de Linux llega en UTF-8. Leerlas con la misma
# codificacion devuelve basura, asi que hay una funcion para cada caso.

# Los argumentos se pasan como UN array, no con ValueFromRemainingArguments:
# ese modo hace que PowerShell se coma el `--` que separa los argumentos de
# wsl.exe del comando de Linux, y la distro acaba interpretando su propio
# nombre como si fuera el comando a ejecutar.
#
# Y el parametro no puede llamarse $Args: es una variable automatica, y el
# splatting `@Args` usaria esa en vez de la del parametro.

# Para subcomandos de wsl.exe (--list, --status…), que salen en UTF-16LE.
function Invoke-WslCli([string[]]$WslArgs) {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        (& wsl.exe @WslArgs 2>&1) -replace "`0", ''
    } finally { [Console]::OutputEncoding = $prev }
}

# Para comandos ejecutados DENTRO de la distro, que salen en UTF-8.
function Invoke-WslCmd([string[]]$WslArgs) {
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        & wsl.exe @WslArgs 2>&1
    } finally { [Console]::OutputEncoding = $prev }
}

Write-Host ""
Write-Host "  Instalador de WSL + dotfiles" -ForegroundColor White
Write-Host "  6 pasos · idempotente: se puede re-ejecutar" -ForegroundColor DarkGray

if (-not (Test-Admin)) {
    Die "Hace falta PowerShell como administrador (los pasos 1 y 2 tocan features de Windows).`n     Boton derecho en PowerShell -> Ejecutar como administrador."
}

if (-not $User) { $User = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '' }
if (-not $User) { Die "No se pudo deducir un nombre de usuario valido; pasa -User" }

# ============================================================ 1. Features
Say "1/6 · WSL2"

$needReboot = $false
foreach ($f in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f).State
    if ($state -ne 'Enabled') {
        Note "habilitando $f…"
        $r = Enable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -All
        if ($r.RestartNeeded) { $needReboot = $true }
    } else { Ok "$f ya habilitado" }
}

if ($needReboot) {
    Warn "Windows necesita reiniciarse para activar WSL."
    Note "Reinicia y vuelve a ejecutar este script: continuara donde iba."
    exit 0
}

# El kernel se actualiza aparte de las features.
try { & wsl.exe --update --web-download 2>&1 | Out-Null } catch {}
& wsl.exe --set-default-version 2 2>&1 | Out-Null
Ok "WSL2 listo"

# ============================================================ 2. .wslconfig
Say "2/6 · Configuracion de WSL (.wslconfig)"

$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
if (Test-Path $wslConfig) {
    Ok "ya existe $wslConfig (no se toca)"
    Note "borralo y re-ejecuta si quieres el de referencia"
} else {
    # La mitad de la RAM, redondeada hacia abajo, con un minimo de 4 GB: WSL2
    # crece hasta el limite y no siempre devuelve la memoria a Windows.
    $totalGb = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $memGb   = [math]::Max(4, [math]::Floor($totalGb / 2))
    @"
[wsl2]
memory=${memGb}GB
processors=$([Environment]::ProcessorCount)
swap=4GB

# Devuelve memoria a Windows en vez de retenerla hasta el reinicio.
autoMemoryReclaim=gradual
# El disco virtual no crece de forma indefinida.
sparseVhd=true

# Modo espejo: WSL replica las interfaces de Windows en vez de vivir tras un
# NAT, y comparten loopback. Si usas una VPN corporativa y algo deja de
# resolver, comenta esta linea y las dos siguientes.
networkingMode=mirrored
dnsTunneling=true
autoProxy=true

[experimental]
hostAddressLoopback=true
"@ | Set-Content -Path $wslConfig -Encoding UTF8
    Ok "escrito $wslConfig (${memGb}GB RAM, $([Environment]::ProcessorCount) CPUs)"
}

# ============================================================ 3. Distro
Say "3/6 · $Distro"

$installed = @(Invoke-WslCli @('--list','--quiet') |
               ForEach-Object { $_.Trim() } | Where-Object { $_ })

# Si ya hay una Ubuntu registrada con otro nombre ("Ubuntu" a secas, que es como
# la registra `wsl --install` sin argumentos), se usa esa en vez de instalar una
# segunda distro en paralelo.
if ($installed -notcontains $Distro) {
    $similar = $installed | Where-Object { $_ -like "$($Distro.Split('-')[0])*" } | Select-Object -First 1
    if ($similar) {
        Note "ya existe '$similar'; se usara esa en vez de instalar $Distro"
        $Distro = $similar
    }
}

if ($installed -contains $Distro) {
    Ok "$Distro ya instalada"
} else {
    Note "descargando e instalando (unos minutos)…"
    # --no-launch evita el asistente interactivo de creacion de usuario: aqui
    # se crea despues, sin depender de que alguien conteste en una consola.
    & wsl.exe --install -d $Distro --no-launch
    if ($LASTEXITCODE -ne 0) { Die "fallo 'wsl --install -d $Distro'" }
    Ok "$Distro instalada"
}

# --- usuario -----------------------------------------------------------------
$userExists = @(Invoke-WslCmd @('-d',$Distro,'-u','root','--','id','-u',$User) 2>$null) -match '^\d+$'
if ($userExists) {
    Ok "el usuario '$User' ya existe"
} else {
    Note "creando el usuario '$User' con sudo"
    $p1 = Read-Host "  Contrasena para '$User'" -AsSecureString
    $p2 = Read-Host "  Reptela"                 -AsSecureString
    $s1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
    $s2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
    if ($s1 -ne $s2)  { Die "las contrasenas no coinciden" }
    if (-not $s1)     { Die "la contrasena no puede estar vacia" }

    & wsl.exe -d $Distro -u root -- useradd -m -s /bin/bash -G sudo $User
    if ($LASTEXITCODE -ne 0) { Die "no se pudo crear el usuario" }
    # chpasswd por stdin: asi la contrasena no aparece en la linea de comandos
    # ni, por tanto, en el historial de procesos.
    "${User}:${s1}" | & wsl.exe -d $Distro -u root -- chpasswd
    if ($LASTEXITCODE -ne 0) { Die "no se pudo fijar la contrasena" }
    $s1 = $null; $s2 = $null

    # Usuario por defecto de la distro, para no entrar como root.
    & wsl.exe -d $Distro -u root -- bash -c "printf '[user]\ndefault=$User\n' >> /etc/wsl.conf"
    & wsl.exe --terminate $Distro 2>&1 | Out-Null
    Ok "usuario '$User' creado, en el grupo sudo y por defecto"
}

# ============================================================ 4. Fuente
Say "4/6 · JetBrainsMono Nerd Font"

$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$faces   = @{
    'JetBrainsMonoNerdFont-Regular.ttf'    = 'JetBrainsMono Nerd Font (TrueType)'
    'JetBrainsMonoNerdFont-Bold.ttf'       = 'JetBrainsMono Nerd Font Bold (TrueType)'
    'JetBrainsMonoNerdFont-Italic.ttf'     = 'JetBrainsMono Nerd Font Italic (TrueType)'
    'JetBrainsMonoNerdFont-BoldItalic.ttf' = 'JetBrainsMono Nerd Font Bold Italic (TrueType)'
}

if (Test-Path (Join-Path $fontDir 'JetBrainsMonoNerdFont-Regular.ttf')) {
    Ok "ya instalada"
} else {
    Note "descargando (~130 MB)…"
    $tmp = Join-Path $env:TEMP "nf-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'jbm.zip'
        Invoke-WebRequest -UseBasicParsing -Uri `
            'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' `
            -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        # Se instala en el perfil de usuario y se registra en HKCU: no hace
        # falta tocar C:\Windows\Fonts ni, por tanto, permisos de maquina.
        foreach ($f in $faces.Keys) {
            $src = Join-Path $tmp $f
            if (Test-Path $src) {
                Copy-Item $src (Join-Path $fontDir $f) -Force
                New-ItemProperty -Path $fontKey -Name $faces[$f] `
                    -Value (Join-Path $fontDir $f) -PropertyType String -Force | Out-Null
            }
        }
        Ok "instalada y registrada"
    } catch {
        Warn "no se pudo instalar la fuente: $($_.Exception.Message)"
        Note "hazlo a mano desde nerdfonts.com; sin ella los iconos salen como cuadrados"
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# ============================================================ 5. Terminal
Say "5/6 · Windows Terminal"

if ($SkipTerminal) {
    Note "omitido por -SkipTerminal"
} else {
    $wtSettings = Join-Path $env:LOCALAPPDATA `
        'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path $wtSettings)) {
        Warn "Windows Terminal no esta instalado o no se ha abierto nunca"
        Note "abrelo una vez y re-ejecuta este script"
    } else {
        Copy-Item $wtSettings "$wtSettings.bak-$(Get-Date -f yyyyMMddHHmmss)" -Force
        try {
            $s = Get-Content $wtSettings -Raw | ConvertFrom-Json

            if (-not $s.profiles.defaults) {
                $s.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
            }
            $d = $s.profiles.defaults
            $d | Add-Member -NotePropertyName font `
                 -NotePropertyValue ([pscustomobject]@{ face = 'JetBrainsMono Nerd Font'; size = 11 }) -Force
            $d | Add-Member -NotePropertyName colorScheme    -NotePropertyValue 'Minimal Dark' -Force
            $d | Add-Member -NotePropertyName padding        -NotePropertyValue '14, 12, 14, 6' -Force
            $d | Add-Member -NotePropertyName cursorShape    -NotePropertyValue 'bar' -Force
            $d | Add-Member -NotePropertyName scrollbarState -NotePropertyValue 'hidden' -Force
            $d | Add-Member -NotePropertyName bellStyle      -NotePropertyValue 'none' -Force
            $d | Add-Member -NotePropertyName useAcrylic     -NotePropertyValue $false -Force
            $d | Add-Member -NotePropertyName historySize    -NotePropertyValue 10000 -Force

            $scheme = [pscustomobject]@{
                name='Minimal Dark'; background='#121216'; foreground='#E6E6E6'
                cursorColor='#E6E6E6'; selectionBackground='#2E2E36'
                black='#1C1C22'; brightBlack='#4A4A55'
                red='#D96B6B';   brightRed='#E88C8C'
                green='#8FBF8F'; brightGreen='#A8D5A8'
                yellow='#D9C08C';brightYellow='#E8D4A8'
                blue='#8AA8D9';  brightBlue='#A8C0E8'
                purple='#B49AD9';brightPurple='#C9B4E8'
                cyan='#8FC7C7';  brightCyan='#A8DADA'
                white='#D0D0D0'; brightWhite='#FFFFFF'
            }
            $others = @($s.schemes | Where-Object { $_.name -ne 'Minimal Dark' })
            $s.schemes = @($others + $scheme)

            # Perfil de la distro como predeterminado, arrancando en $HOME:
            # los perfiles de WSL abren en /mnt/c/... por defecto, que es DrvFs
            # y va muy por detras del filesystem de Linux en I/O.
            $prof = $s.profiles.list | Where-Object {
                $_.source -eq 'Windows.Terminal.Wsl' -and $_.name -like "*$($Distro.Split('-')[0])*"
            } | Select-Object -First 1
            if ($prof) {
                $prof | Add-Member -NotePropertyName commandline `
                        -NotePropertyValue "wsl.exe -d $Distro --cd ~" -Force
                $prof | Add-Member -NotePropertyName hidden -NotePropertyValue $false -Force
                $s.defaultProfile = $prof.guid
                Ok "perfil '$($prof.name)' por defecto, arrancando en ~"
            } else {
                Warn "no se encontro el perfil de $Distro; abre Windows Terminal una vez"
            }

            $s | ConvertTo-Json -Depth 32 | Set-Content $wtSettings -Encoding UTF8
            Ok "fuente y tema aplicados (copia de seguridad junto al original)"
        } catch {
            Warn "no se pudo modificar settings.json: $($_.Exception.Message)"
        }
    }
}

# ============================================================ 6. Dotfiles
Say "6/6 · Dotfiles"

Note "a partir de aqui manda el asistente de Linux: te preguntara tus datos."
Write-Host ""
# bash <(...) y no `curl | bash`: en la tuberia el script heredaria el stdin de
# curl y el asistente no podria leer las respuestas.
& wsl.exe -d $Distro -u $User -- bash -lic `
    "bash <(curl -fsSL '$RepoRaw/bootstrap.sh?`$(date +%s)')"

Write-Host ""
Write-Host "  ✓ Listo" -ForegroundColor Green
Note "Abre Windows Terminal: deberia entrar directo en $Distro, con el prompt nuevo."
Note "Si los iconos salen como cuadrados, cierra Windows Terminal del todo y reabrelo."
Write-Host ""
