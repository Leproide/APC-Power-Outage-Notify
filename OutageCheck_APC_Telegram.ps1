# Telegram Parameters
$telegramToken = "your:token"  # Your bot token
$chatId = "-100123456789"  # Your chat ID
$telegramUrl = "https://api.telegram.org/bot$telegramToken/sendMessage"

# Parametri dell'evento
$eventSource = "APC UPS Service"
$timeThreshold = 10  # Seconds age check (Default 3 seconds)

# Funzione per inviare notifiche a Telegram
function Send-TelegramNotification {
    param (
        [string]$messageText
    )

    $body = @{
        "chat_id" = $chatId
        "text" = $messageText
    }

    try {
        $response = Invoke-RestMethod -Uri $telegramUrl -Method Post -ContentType "application/json" -Body ($body | ConvertTo-Json)
        Write-Output "Notifica Telegram inviata con successo: $($response.ok)"
    } catch {
        Write-Error "Errore durante l'invio della notifica Telegram: $_"
        if ($_.Exception.InnerException -match "No connection could be made because the target machine actively refused it") {
            Write-Error "Cant connect to Telegram server. Check internet connection and BOT options"
        }
    }
}

# Funzione per controllare un evento specifico
function Check-EventAndNotify {
    param (
        [int]$eventId,
        [string]$messageText
    )
    
    $event = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=$eventId; ProviderName=$eventSource} -MaxEvents 1

    if ($event) {
        $eventTime = [DateTime]$event.TimeCreated
        $currentTime = Get-Date
        $timeDifference = ($currentTime - $eventTime).TotalSeconds

        if ($timeDifference -le $timeThreshold) {
            Send-TelegramNotification -messageText $messageText
        } else {
            Write-Output "Evento $eventId trovato, ma è più vecchio di $timeThreshold secondi. Nessuna notifica inviata."
        }
    } else {
        Write-Output "Nessun evento $eventId rilevato."
    }
}

# Controllo dell'evento 174 (Interruzione di alimentazione)
Check-EventAndNotify -eventId 174 -messageText "Power Outage on $($env:COMPUTERNAME) - UPS on battery."

# Controllo dell'evento 61455 (Alimentazione ripristinata)
Check-EventAndNotify -eventId 61455 -messageText "Power restored on $($env:COMPUTERNAME)"
