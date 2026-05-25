# ============================================================
# ANTIVIRUS DETECTOR
# Clean Output - Only Shows Antivirus Names
# ============================================================

Clear-Host

$AVProducts = @{
    "Microsoft Defender" = @(
        "WinDefend","WdNisSvc","Sense",
        "MsMpEng","NisSrv",
        "Microsoft Defender","Windows Defender"
    )

    "Avast" = @(
        "Avast","AvastSvc","AvastUI",
        "aswBcc","aswSP"
    )

    "AVG" = @(
        "AVG","AVGSvc","AVGUI"
    )

    "Kaspersky" = @(
        "Kaspersky","AVP","klavsvc","KLIF"
    )

    "Bitdefender" = @(
        "Bitdefender","BDESVC",
        "BDAntivirus","bdagent","vsserv"
    )

    "Norton/Symantec" = @(
        "Norton","Symantec",
        "NortonSecurity","ccSvcHst","SymCorpUI"
    )

    "McAfee/Trellix" = @(
        "McAfee","Trellix",
        "mfemms","mfevtp","McShield"
    )

    "Malwarebytes" = @(
        "Malwarebytes","MBAMService",
        "MBAM","mbamtray"
    )

    "Sophos" = @(
        "Sophos","SAVService","SophosHealth"
    )

    "Trend Micro" = @(
        "Trend Micro","Trend",
        "TmProxy","TmCCSF","ntrtscan"
    )

    "ESET" = @(
        "ESET","ekrn","egui"
    )

    "Panda" = @(
        "Panda","PSUAService","PavFnSvr"
    )

    "Avira" = @(
        "Avira","Avira.ServiceHost","avgnt"
    )

    "F-Secure" = @(
        "F-Secure","FSAV","fshoster"
    )

    "Webroot" = @(
        "Webroot","WRSA"
    )

    "Comodo" = @(
        "Comodo","cmdagent","cis"
    )

    "G DATA" = @(
        "G DATA","AVKService"
    )

    "CrowdStrike" = @(
        "CrowdStrike","CSFalconService","falcon-sensor"
    )

    "SentinelOne" = @(
        "SentinelOne","SentinelAgent","SentinelService"
    )

    "Cortex XDR" = @(
        "Cortex XDR","Traps","cyserver","cytray"
    )
}

$Detected = New-Object System.Collections.Generic.HashSet[string]

# ============================================================
# INSTALLED PROGRAMS
# ============================================================

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$InstalledPrograms = @()

foreach ($Path in $RegistryPaths) {
    try {
        $InstalledPrograms += Get-ItemProperty $Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object -ExpandProperty DisplayName
    }
    catch {}
}

# ============================================================
# SERVICES
# ============================================================

$Services = Get-Service -ErrorAction SilentlyContinue

# ============================================================
# PROCESSES
# ============================================================

$Processes = Get-Process -ErrorAction SilentlyContinue

# ============================================================
# WINDOWS SECURITY CENTER
# ============================================================

$SecurityCenter = @()

try {
    $SecurityCenter = Get-CimInstance `
        -Namespace "root\SecurityCenter2" `
        -ClassName AntiVirusProduct `
        -ErrorAction Stop
}
catch {}

# ============================================================
# DETECTION ENGINE
# ============================================================

foreach ($Product in $AVProducts.Keys) {

    $Patterns = $AVProducts[$Product]
    $Found = $false

    # Installed programs
    foreach ($Program in $InstalledPrograms) {
        foreach ($Pattern in $Patterns) {
            if ($Program -match [regex]::Escape($Pattern)) {
                $Found = $true
            }
        }
    }

    # Services
    foreach ($Service in $Services) {
        foreach ($Pattern in $Patterns) {
            if (
                $Service.Name -match [regex]::Escape($Pattern) -or
                $Service.DisplayName -match [regex]::Escape($Pattern)
            ) {
                $Found = $true
            }
        }
    }

    # Processes
    foreach ($Process in $Processes) {
        foreach ($Pattern in $Patterns) {
            if ($Process.ProcessName -match [regex]::Escape($Pattern)) {
                $Found = $true
            }
        }
    }

    # Windows Security Center
    foreach ($AV in $SecurityCenter) {
        foreach ($Pattern in $Patterns) {
            if ($AV.displayName -match [regex]::Escape($Pattern)) {
                $Found = $true
            }
        }
    }

    if ($Found) {
        $Detected.Add($Product) | Out-Null
    }
}

# ============================================================
# OUTPUT
# ============================================================

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Detected Antivirus Products" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

if ($Detected.Count -eq 0) {

    Write-Host "No antivirus products detected." -ForegroundColor Green

}
else {

    $Detected |
    Sort-Object |
    ForEach-Object {

        Write-Host " - $_" -ForegroundColor Green

    }
}

Write-Host ""
