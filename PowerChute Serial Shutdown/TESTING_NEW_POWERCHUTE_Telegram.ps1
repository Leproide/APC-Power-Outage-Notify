# =========================
# Telegram Parameters
# =========================
$telegramToken = "your:token"   # Your bot token
$chatId        = "-1234567890"  # Your chat ID
$telegramUrl   = "https://api.telegram.org/bot$telegramToken/sendMessage"

# =========================
# Event Log Parameters
# =========================
$logName       = "Application"
$eventSources  = @(
    "APCPBEAgent"
    # Optional legacy source:
    # "APC UPS Service"
)

$timeThreshold = 10  # Seconds. Send notification only if the event is recent.

# =========================
# Event ID -> Message Map
# =========================
$eventMap = @{
    1000 = "APC - Monitoring stopped"
    1001 = "APC - Monitoring started"
    1002 = "APC - Communications established"
    1003 = "Power restored on $($env:COMPUTERNAME)"
    1004 = "APC - UPS self-test passed"
    1005 = "APC - Administrative shutdown scheduled"
    1006 = "APC - Shutdown cancelled"
    1007 = "APC - UPS self-test initiated"
    1009 = "APC - UPS battery replaced"
    1010 = "APC - UPS battery charge in range"
    1013 = "APC - Overload condition solved"
    1014 = "APC - Runtime calibration started"
    1015 = "APC - Runtime calibration finished"
    1016 = "APC - System shutdown starting"
    1017 = "APC - UPS returned from bypass"
    1020 = "APC - Battery communication established"
    1025 = "APC - Shutdown in progress"
    1026 = "APC - Administrative shutdown pending"
    1027 = "APC - Administrative shutdown cancelled"
    1033 = "APC - Battery added"
    1034 = "APC - Battery removed"
    1040 = "APC - Bypass contactor OK"
    1041 = "APC - Bypass relay normal"
    1042 = "APC - Bypass user initiated"
    1050 = "APC - Battery disconnected"
    1051 = "APC - Battery reconnected"
    1052 = "APC - Battery installed"
    1053 = "APC - Sufficient runtime available"
    1060 = "APC - AVR trim no longer active"
    1061 = "APC - AVR boost no longer active"
    1102 = "APC - UPS internal temperature in bounds"
    1200 = "APC - Base module fan normal"
    1201 = "APC - System level fan normal"
    1202 = "APC - Site wiring normal"
    1203 = "APC - Battery charger normal"
    1204 = "APC - Main relay normal"
    1205 = "APC - Inverter normal"
    1206 = "APC - Bypass power supply normal"
    1207 = "APC - Output load in range"
    1208 = "APC - UPS internal temperature warning"
    1350 = "APC - Bypass ended"
    1366 = "APC - Bypass enabled"
    2000 = "Power outage on $($env:COMPUTERNAME) - UPS on battery."
    2002 = "APC - AVR boost active"
    2003 = "APC - Low battery condition"
    2004 = "APC - Runtime calibration aborted"
    2007 = "APC - AVR trim active"
    2030 = "APC - Smart cell signal returned"
    2037 = "APC - Bypass contactor failed"
    2040 = "APC - Bypass relay malfunction"
    2041 = "APC - Bypass contactor stuck in bypass"
    2042 = "APC - Bypass contactor stuck in on position"
    2043 = "APC - Bypass maintenance warning"
    2044 = "APC - Bypass internal fault"
    2050 = "APC - Invalid shutdown delay"
    2060 = "APC - Time on battery threshold exceeded"
    2206 = "APC - Account locked out"
    2207 = "APC - Account no longer locked out"
    2208 = "APC - Invalid user login"
    2209 = "APC - User logged off"
    2210 = "APC - User logged on"
    2211 = "APC - Audible alarm enabled"
    2212 = "APC - Audible alarm disabled"
    3000 = "APC - Lost communication with UPS"
    3001 = "APC - UPS output overload"
    3002 = "APC - UPS self-test failed"
    3003 = "APC - UPS battery is discharged"
    3004 = "APC - Communication lost while on battery"
    3005 = "APC - Communication not established"
    3006 = "APC - Battery communication lost"
    3010 = "APC - Smart cell signal lost"
    3014 = "APC - Base module fan fault"
    3015 = "APC - Bypass power supply failure"
    3016 = "APC - Battery needs replacing"
    3017 = "APC - System level fan fault"
    3018 = "APC - Main relay malfunction"
    3020 = "APC - Site wiring fault"
    3021 = "APC - Battery charger failure"
    3022 = "APC - Inverter fault"
    3030 = "APC - Insufficient runtime available"
    3031 = "APC - Output load threshold exceeded"
    3107 = "APC - Maximum internal temperature exceeded"
    3123 = "APC - Frequent overvoltage warning"
    3124 = "APC - Frequent undervoltage warning"
    3125 = "APC - Extended overvoltage warning"
    3126 = "APC - Extended undervoltage warning"
}

# =========================
# Send Telegram Notification
# =========================
function Send-TelegramNotification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MessageText
    )

    $body = @{
        chat_id = $chatId
        text    = $MessageText
    }

    try {
        $response = Invoke-RestMethod -Uri $telegramUrl -Method Post -ContentType "application/json" -Body ($body | ConvertTo-Json -Compress) -ErrorAction Stop
        Write-Host "Telegram notification sent successfully: $($response.ok)"
    }
    catch {
        Write-Error "Error sending Telegram notification: $($_.Exception.Message)"
    }
}

# =========================
# Get Latest Matching Event
# =========================
function Get-LatestMatchingEvent {
    param(
        [Parameter(Mandatory = $true)]
        [int]$EventId
    )

    try {
        Get-WinEvent -FilterHashtable @{ LogName = $logName; Id = $EventId } -MaxEvents 25 -ErrorAction Stop |
            Where-Object { $eventSources -contains $_.ProviderName } |
            Select-Object -First 1
    }
    catch {
        $null
    }
}

# =========================
# Check Event and Notify
# =========================
function Check-EventAndNotify {
    param(
        [Parameter(Mandatory = $true)]
        [int]$EventId
    )

    if (-not $eventMap.ContainsKey($EventId)) {
        return
    }

    $event = Get-LatestMatchingEvent -EventId $EventId

    if (-not $event) {
        Write-Host "No event $EventId found for the selected providers."
        return
    }

    $eventTime = $event.TimeCreated
    if (-not $eventTime) {
        Write-Host "Event $EventId found but TimeCreated is missing."
        return
    }

    $ageSeconds = ([DateTime]::Now - $eventTime).TotalSeconds

    if ($ageSeconds -le $timeThreshold) {
        Send-TelegramNotification -MessageText $eventMap[$EventId]
    }
    else {
        Write-Host "Event $EventId found but it is $([math]::Round($ageSeconds,2)) seconds old. Ignored."
    }
}

# =========================
# Events to Check
# =========================
$eventsToCheck = @(
    2000,  # UPS on battery
    1003,  # Power restored
    1004,  # Self-test passed
    1009,  # Battery replaced
    1051,  # Battery reconnected
    1052,  # Battery installed
    3000,  # Lost communication with UPS
    3002,  # Self-test failed
    3004,  # Communication lost while on battery
    3006,  # Battery communication lost
    3016,  # Battery needs replacing
    3030,  # Insufficient runtime available
    3107,  # Maximum internal temperature exceeded
    3123,  # Frequent overvoltage warning
    3124,  # Frequent undervoltage warning
    3125,  # Extended overvoltage warning
    3126   # Extended undervoltage warning
)

foreach ($id in $eventsToCheck) {
    Check-EventAndNotify -EventId $id
}
