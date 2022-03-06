ruleset profile {
    meta {
        use module twilio_sdk alias twilio 
            with
                twilio_account_sid = meta:rulesetConfig{"twilio_account_sid"}
                twilio_auth_token = meta:rulesetConfig{"twilio_auth_token"}
    }

    global {
        from = "+13854858486"
        to = "+18015497921"
    }

    rule send_threshold_alert {
        select when profile send_threshold_alert

        pre {
            sensor_name = event:attrs{"sensor_name"}
            threshold = event:attrs{"threshold"}
            temperature = event:attrs{"temperature"}
            message = <<
            New temperature reading of #{temperature}° #{sensor_name} exceeded its #{threshold}° threshold. 
            >>
        }

        twilio:send_message(message, from, to)
    }
}