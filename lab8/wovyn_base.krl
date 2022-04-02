
ruleset wovyn_base {

    meta {
        use module sensor_profile alias sensor
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
                if (temperature > sensor:threshold());
        }
    }

}