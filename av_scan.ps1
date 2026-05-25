# ============================================================
# ANTIVIRUS DETECTOR - CLEAN OUTPUT
# ============================================================

function Get-AntivirusStatus {
    Write-Host "[+] Starting Antivirus Scan..." -ForegroundColor Cyan
    $found = @()

    # ==================== SERVICES ====================
    Write-Host "`n[ SERVICES ]" -ForegroundColor Yellow
    $services = @(
        "WinDefend", "WdNisSvc", "Sense",                    # Windows Defender
        "MBAMService", "Malwarebytes",                        # Malwarebytes
        "Avast", "aswBcc", "aswSP", "aswIDSAg",              # Avast
        "AVP", "KLIF", "klavsvc", "Kaspersky",               # Kaspersky
        "BDESVC", "bdagent", "Bitdefender Agent",             # Bitdefender
        "NortonSecurity", "Symantec", "ccSvcHst",            # Norton / Symantec
        "McAfee", "mfemms", "mfevtp",                         # McAfee
        "Sophos", "SAVService", "Sophos Agent",               # Sophos
        "TmProxy", "TmCCSF"                                   # Trend Micro
    )

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            $status = if ($service.Status -eq "Running") { "RUNNING" } else { "STOPPED" }
            Write-Host "  [$svc] $status" -ForegroundColor Red
            $found += "Service: $svc ($status)"
        }
    }

    # ==================== PROCESSES ====================
    Write-Host "`n[ PROCESSES ]" -ForegroundColor Yellow
    $processes = @(
        "MsMpEng", "NisSrv", "SecurityHealthService",         # Defender
        "AvastUI", "AvastSvc",                                # Avast
        "avp", "avpui",                                       # Kaspersky
        "bdagent", "BitDefender",                             # Bitdefender
        "MBAM", "Malwarebytes",                               # Malwarebytes
        "SymCorpUI", "ccSvcHst",                              # Norton
        "McAfee", "mfevtp"                                    # McAfee
    )

    foreach ($proc in $processes) {
        if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
            Write-Host "  [$proc.exe] RUNNING" -ForegroundColor Red
            $found += "Process: $proc.exe"
        }
    }

    # ==================== INSTALLED PROGRAMS ====================
    Write-Host "`n[ INSTALLED PROGRAMS ]" -ForegroundColor Yellow
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $avKeywords = @("Avast","AVG","Kaspersky","Bitdefender","Norton","McAfee","Malwarebytes","Sophos","ESET","Trend Micro","Panda","Avira")

    foreach ($path in $uninstallPaths) {
        if (Test-Path $path) {
            Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
                $displayName = (Get-ItemProperty $_.PSPath).DisplayName
                if ($displayName) {
                    foreach ($keyword in $avKeywords) {
                        if ($displayName -match $keyword) {
                            Write-Host "  [INSTALLED] $displayName" -ForegroundColor Red
                            $found += "Installed: $displayName"
                            break
                        }
                    }
                }
            }
        }
    }

    # ==================== FINAL SUMMARY ====================
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    if ($found.Count -gt 0) {
        Write-Host "[!] Antivirus / Security Products Detected: $($found.Count)" -ForegroundColor Red
    } else {
        Write-Host "[+] No known antivirus products detected." -ForegroundColor Green
    }
    Write-Host "="*60 -ForegroundColor Cyan

    return $found
}

# Execute the scan
$results = Get-AntivirusStatus