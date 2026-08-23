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
  Usuario de Linux. Si la distro ya tiene uno, se reutiliza; si no, se
  pregunta proponiendo tu nombre de Windows en minusculas.

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

# --- entrada -------------------------------------------------------------------
# Enter acepta el valor entre corchetes; se pregunta una sola vez.
function Field($label, $default) {
    $l = "  {0,-24}" -f $label
    if ($default) { Write-Host "$l [$default] " -NoNewline -ForegroundColor White }
    else          { Write-Host "$l " -NoNewline -ForegroundColor White }
    $in = Read-Host
    if ([string]::IsNullOrWhiteSpace($in)) { $default } else { $in.Trim() }
}

function YesNo($label, $default) {
    $hint = if ($default) { 'S/n' } else { 's/N' }
    Write-Host ("  {0,-24} [{1}] " -f $label, $hint) -NoNewline -ForegroundColor White
    $in = Read-Host
    switch -Regex ($in) { '^[SsYy]' { $true } '^[Nn]' { $false } default { $default } }
}

function Num($label, $default, $min, $max) {
    while ($true) {
        $v = Field $label $default
        $n = 0
        if ([int]::TryParse("$v", [ref]$n) -and $n -ge $min -and $n -le $max) { return $n }
        Warn "escribe un numero entre $min y $max"
    }
}

# --- .wslconfig ----------------------------------------------------------------
# El fichero se lee y se escribe siempre en UTF-8 sin BOM. Get-Content y
# Set-Content sin -Encoding usan la ANSI del sistema en PowerShell 5.1, que
# destroza los acentos de los comentarios; y -Encoding UTF8 escribe CON BOM,
# que aqui no estaba.
function Read-IniLines([string]$path) {
    # Sin la coma de "array envuelto": aqui @(...) no la desenvolveria y el
    # fichero entero acabaria en un unico elemento.
    [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)
}
function Write-IniLines([string]$path, [string[]]$lines) {
    [System.IO.File]::WriteAllLines($path, $lines, (New-Object System.Text.UTF8Encoding $false))
}

# Devuelve el valor de una clave del fichero, o $null.
function Get-IniValue($lines, $key) {
    foreach ($l in $lines) {
        if ($l -match "^\s*$key\s*=\s*(.+?)\s*$") { return $Matches[1] }
    }
    $null
}

# Actualiza claves conservando TODO lo demas: comentarios, orden y claves que
# este script no gestiona. Reemplazar el fichero entero borraria las notas que
# su dueno haya escrito, que suelen ser justo lo que costo averiguar.
function Merge-Ini {
    # IDictionary y no [hashtable]: un [ordered] convertido a hashtable pierde
    # el orden de insercion, y las claves saldrian barajadas.
    param([string[]]$Lines, [string]$Section, [System.Collections.IDictionary]$Pairs)

    $out = New-Object System.Collections.Generic.List[string]
    $out.AddRange([string[]]$Lines)

    # Limites de la seccion: desde su cabecera hasta la siguiente, o el final.
    $start = -1
    for ($i = 0; $i -lt $out.Count; $i++) {
        if ($out[$i] -match "^\s*\[$Section\]\s*$") { $start = $i; break }
    }
    if ($start -lt 0) {
        if ($out.Count -gt 0 -and $out[$out.Count-1].Trim() -ne '') { $out.Add('') }
        $out.Add("[$Section]")
        $start = $out.Count - 1
    }
    $end = $out.Count
    for ($i = $start + 1; $i -lt $out.Count; $i++) {
        if ($out[$i] -match '^\s*\[.+\]\s*$') { $end = $i; break }
    }

    # $at avanza con cada insercion para que las claves nuevas queden en el
    # orden en que se pasaron, no del reves.
    $at = $start + 1
    foreach ($k in $Pairs.Keys) {
        $done = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($out[$i] -match "^\s*$k\s*=") { $out[$i] = "$k=$($Pairs[$k])"; $done = $true; break }
        }
        if (-not $done) {
            # Justo tras la cabecera, para que no queden separadas de su seccion
            # por los comentarios que ya hubiera.
            $out.Insert($at, "$k=$($Pairs[$k])")
            $at++; $end++
        }
    }
    $out.ToArray()
}

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


# ============================================================ 0. Wizard
Say "1/7 · Configuracion"

$totalGb = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$cpus    = [Environment]::ProcessorCount
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$haveWslConfig = Test-Path $wslConfig

Note "Enter acepta el valor entre corchetes."
Write-Host ""
Write-Host "  Sistema" -ForegroundColor Cyan
$Distro = Field "Distribucion" $Distro

# 'skip' conservar | 'merge' actualizar claves | 'replace' empezar de cero
$W_ConfigMode = 'merge'
$defMem  = [math]::Max(4, [math]::Floor($totalGb / 2))
$defCpus = $cpus
$defSwap = 4
$defMirror = $true

if ($haveWslConfig) {
    $cur = @(Read-IniLines $wslConfig)
    Write-Host ""
    Write-Host "  Ya tienes un .wslconfig" -ForegroundColor Cyan
    Note $wslConfig
    # Se ensena lo que hay antes de preguntar: tocar a ciegas un fichero que
    # alguien ajusto a mano es justo lo que no debe hacer un instalador.
    $cur | Where-Object { $_ -match '^\s*(memory|processors|swap|networkingMode|dnsTunneling|autoProxy|hostAddressLoopback|autoMemoryReclaim|sparseVhd)\s*=' } |
        ForEach-Object { Write-Host ("      " + $_.Trim()) -ForegroundColor DarkGray }

    # Los valores que ya estan pasan a ser la propuesta por defecto.
    $n = 0
    $v = Get-IniValue $cur 'memory';     if ($v -and [int]::TryParse(($v -replace '(?i)gb'), [ref]$n)) { $defMem  = $n }
    $v = Get-IniValue $cur 'processors'; if ($v -and [int]::TryParse($v, [ref]$n))                     { $defCpus = $n }
    $v = Get-IniValue $cur 'swap';       if ($v -and [int]::TryParse(($v -replace '(?i)gb'), [ref]$n)) { $defSwap = $n }
    $v = Get-IniValue $cur 'networkingMode'; if ($v) { $defMirror = ($v -match '(?i)mirrored') }

    Write-Host ""
    Note "  [1] conservarlo tal cual"
    Note "  [2] actualizar solo estas claves, respetando tus comentarios"
    Note "  [3] reemplazarlo entero por el de referencia"
    $ans = Field "Que hago" "2"
    switch ("$ans".Trim()) {
        '1'     { $W_ConfigMode = 'skip' }
        '3'     { $W_ConfigMode = 'replace' }
        default { $W_ConfigMode = 'merge' }
    }
    if ($W_ConfigMode -eq 'skip') { Note "se conserva tal cual" }
}

if ($W_ConfigMode -ne 'skip') {
    Write-Host ""
    Write-Host "  Recursos de WSL" -ForegroundColor Cyan
    Note "Detectado: ${totalGb}GB de RAM, $cpus CPUs"
    $W_Mem   = Num   "Memoria (GB)" $defMem  2 $totalGb
    # Lo que WSL toma se lo quita a Windows: mejor verlo antes de seguir que
    # descubrirlo cuando el escritorio empieza a tirar de swap.
    $left = $totalGb - $W_Mem
    if ($left -lt 4) { Warn "a Windows solo le quedarian ${left}GB; puede ir justo" }
    else             { Note "a Windows le quedan ${left}GB" }
    $W_Cpus  = Num   "CPUs"         $defCpus 1 $cpus
    $W_Swap  = Num   "Swap (GB)"    $defSwap 0 64
    Write-Host ""
    Write-Host "  Red" -ForegroundColor Cyan
    Note "El modo espejo comparte el loopback con Windows, pero rompe"
    Note "algunas VPN corporativas. Si usas una, responde que no."
    $W_Mirror = YesNo "Modo espejo" $defMirror
}

Write-Host ""
Write-Host "  Windows" -ForegroundColor Cyan
$W_Font     = YesNo "Instalar Nerd Font"   $true
$W_Terminal = if ($SkipTerminal) { $false } else { YesNo "Configurar Terminal" $true }
Write-Host ""

# ============================================================ 1. Features
Say "2/7 · WSL2"

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
Say "3/7 · Configuracion de WSL (.wslconfig)"

if ($W_ConfigMode -eq 'skip') {
    Ok "conservado el $wslConfig que ya tenias"
} else {
    if ($haveWslConfig) {
        $bak = "$wslConfig.bak-$(Get-Date -f yyyyMMddHHmmss)"
        Copy-Item $wslConfig $bak -Force
        Note "copia del anterior en $bak"
    }

    $wsl2 = [ordered]@{
        memory            = "${W_Mem}GB"
        processors        = "$W_Cpus"
        swap              = "${W_Swap}GB"
        autoMemoryReclaim = 'gradual'   # devuelve RAM a Windows sin reiniciar
        sparseVhd         = 'true'      # el disco virtual no crece sin fin
    }
    if ($W_Mirror) {
        # Modo espejo: WSL replica las interfaces de Windows en vez de vivir
        # tras un NAT, y comparten loopback.
        $wsl2['networkingMode'] = 'mirrored'
        $wsl2['dnsTunneling']   = 'true'
        $wsl2['autoProxy']      = 'true'
    }

    if ($W_ConfigMode -eq 'merge' -and $haveWslConfig) {
        # Solo se tocan las claves de arriba: el resto del fichero, comentarios
        # incluidos, queda como estaba.
        $lines = @(Read-IniLines $wslConfig)
        $lines = Merge-Ini -Lines $lines -Section 'wsl2' -Pairs $wsl2
        if ($W_Mirror) {
            # hostAddressLoopback va en [experimental]: en [wsl2] WSL la rechaza
            # con "Unknown key".
            $lines = Merge-Ini -Lines $lines -Section 'experimental' -Pairs @{ hostAddressLoopback = 'true' }
        }
        Write-IniLines $wslConfig $lines
        Ok "actualizado $wslConfig (${W_Mem}GB RAM, $W_Cpus CPUs, ${W_Swap}GB swap)"
        Note "tus comentarios y el resto de claves siguen ahi"
    } else {
        $body = New-Object System.Collections.Generic.List[string]
        $body.Add('[wsl2]')
        foreach ($k in $wsl2.Keys) { $body.Add("$k=$($wsl2[$k])") }
        if ($W_Mirror) {
            $body.Add('')
            $body.Add('[experimental]')
            $body.Add('hostAddressLoopback=true')
        } else {
            $body.Add('')
            $body.Add('# Red en NAT, el valor por defecto de WSL: mas compatible con VPN')
            $body.Add('# corporativas. Para llegar a los servicios de Windows desde Linux por')
            $body.Add('# 127.0.0.1 haria falta networkingMode=mirrored.')
        }
        Write-IniLines $wslConfig $body.ToArray()
        Ok "escrito $wslConfig (${W_Mem}GB RAM, $W_Cpus CPUs, ${W_Swap}GB swap)"
    }
}

# ============================================================ 3. Distro
Say "4/7 · $Distro"

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
# Si la distro ya tiene un usuario normal, se usa ESE. Deducirlo del nombre de
# Windows crearia un segundo usuario en una maquina que ya estaba en marcha, con
# otro $HOME y sin nada de lo que ya hubiera configurado.
if (-not $User) {
    # Se lee /etc/passwd entero y se filtra aqui: meter un awk por medio obliga a
    # anidar comillas de PowerShell y de bash, y el $3 se expande antes de llegar.
    $existing = @(Invoke-WslCmd @('-d',$Distro,'-u','root','--','cat','/etc/passwd') 2>$null) |
        ForEach-Object {
            $f = "$_".Split(':')
            if ($f.Count -ge 3) {
                $uid = 0
                if ([int]::TryParse($f[2], [ref]$uid) -and $uid -ge 1000 -and $uid -lt 65534 `
                    -and $f[0] -match '^[a-z_][a-z0-9_-]*$') { $f[0] }
            }
        } | Select-Object -First 1
    if ($existing) {
        $User = $existing
        Ok "usando el usuario que ya existe en $Distro : '$User'"
    }
}

# Sin usuario aun: se propone el de Windows, pero se pregunta. Los nombres de
# Windows suelen no valer en Linux (mayusculas, espacios, acentos).
if (-not $User) {
    $suggested = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', ''
    if ($suggested -notmatch '^[a-z_]') { $suggested = "u$suggested" }
    Note "$Distro no tiene ningun usuario todavia."
    $answer = Read-Host "  Nombre de usuario para Linux [$suggested]"
    $User = if ([string]::IsNullOrWhiteSpace($answer)) { $suggested } else { $answer.Trim() }
}

if ($User -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
    Die "'$User' no es un nombre de usuario valido en Linux (minusculas, digitos, - y _)"
}

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
Say "5/7 · JetBrainsMono Nerd Font"

$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$faces   = @{
    'JetBrainsMonoNerdFont-Regular.ttf'    = 'JetBrainsMono Nerd Font (TrueType)'
    'JetBrainsMonoNerdFont-Bold.ttf'       = 'JetBrainsMono Nerd Font Bold (TrueType)'
    'JetBrainsMonoNerdFont-Italic.ttf'     = 'JetBrainsMono Nerd Font Italic (TrueType)'
    'JetBrainsMonoNerdFont-BoldItalic.ttf' = 'JetBrainsMono Nerd Font Bold Italic (TrueType)'
}

if (-not $W_Font) {
    Note "omitida a peticion tuya"
} elseif (Test-Path (Join-Path $fontDir 'JetBrainsMonoNerdFont-Regular.ttf')) {
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
Say "6/7 · Windows Terminal"

if (-not $W_Terminal) {
    Note "omitido a peticion tuya"
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
Say "7/7 · Dotfiles"

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
