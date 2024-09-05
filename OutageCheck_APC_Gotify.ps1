# Parametri di Gotify
$gotifyUrl = "SERVER URL HERE"
$gotifyToken = "TOKEN HERE"
$GotifyPort = "SERVER PORT HERE"  # Change with your Gotify server port
$gotifyEndpoint = "$($gotifyUrl):$GotifyPort/message"

# Parametri dell'evento
$eventSource = "APC UPS Service"
$timeThreshold = 10  # Chek if the event are new

# Funzione per inviare notifiche a Gotify
function Send-GotifyNotification {
    param (
        [string]$messageTitle,
        [string]$messageBody
    )
    
    $message = @{
        "title" = $messageTitle
        "message" = $messageBody
        "priority" = 5
    }

    try {
        $response = Invoke-RestMethod -Uri $gotifyEndpoint -Method Post -Headers @{ "X-Gotify-Key" = $gotifyToken } -ContentType "application/json" -Body ($message | ConvertTo-Json)
        Write-Output "Notifica inviata con successo: $($response.message)"
    } catch {
        Write-Error "Errore durante l'invio della notifica: $_"
        if ($_.Exception.InnerException -match "No connection could be made because the target machine actively refused it") {
            Write-Error "Cant connect to the server, check your connection"
        }
    }
}

# Funzione per controllare un evento specifico
function Check-EventAndNotify {
    param (
        [int]$eventId,
        [string]$messageTitle,
        [string]$messageBody
    )
    
    $event = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=$eventId; ProviderName=$eventSource} -MaxEvents 1

    if ($event) {
        $eventTime = [DateTime]$event.TimeCreated
        $currentTime = Get-Date
        $timeDifference = ($currentTime - $eventTime).TotalSeconds

        if ($timeDifference -le $timeThreshold) {
            Send-GotifyNotification -messageTitle $messageTitle -messageBody $messageBody
        } else {
            Write-Output "Evento $eventId trovato, ma è più vecchio di $timeThreshold secondi. Nessuna notifica inviata."
        }
    } else {
        Write-Output "Nessun evento $eventId rilevato."
    }
}

# Controllo dell'evento 174 (Interruzione di alimentazione)
Check-EventAndNotify -eventId 174 -messageTitle "Power Outage!" -messageBody "Power Outage on $($env:COMPUTERNAME) - UPS on battery."

# Controllo dell'evento 61455 (Alimentazione ripristinata)
Check-EventAndNotify -eventId 61455 -messageTitle "Power restored" -messageBody "Power restored on $($env:COMPUTERNAME)"
