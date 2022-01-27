
ruleset wovyn_base {
    meta {
        use module twilio_sdk alias twilio 
        with
            twilio_account_sid = meta:rulesetConfig{"twilio_account_sid"}
            twilio_auth_token = meta:rulesetConfig{"twilio_auth_token"}
    }

    global {
        temperature_threshold = 75
    }

    rule process_heartbeat {
        select when wovyn heartbeat genericThing re#.+#

        pre {
            temperature_f = event:attrs{["genericThing", "data", "temperature"]}[0]{"temperatureF"}
        }

        send_directive("process_heartbeat")

        always {
            log info "process_heartbeat"
            raise wovyn event "new_temperature_reading" attributes {
                "temperature": temperature_f,
                "timestamp": time:now()
            }
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        
        pre {
            temperature = event:attrs{"temperature"}.klog("Temperature:")
            timestamp = event:attrs{"timestamp"}.klog("Timestamp:")
        }
        
        always {
            log info "find_high_temps"
            raise wovyn event "threshold_violation" attributes event:attrs
                if (temperature > temperature_threshold);
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            temperature = event:attrs{"temperature"}.klog()
            timestamp = event:attrs{"timestamp"}
            message = << Temperature threshold (#{temperature_threshold}) exceeded: #{temperature} degrees at #{timestamp}>>
        }

        twilio:send_message(message, "+13854858486", "+18015497921")

        always {
            log info << threshold_notification >>
        }
    }

}