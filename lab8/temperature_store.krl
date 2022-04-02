
ruleset temperature_store {

    meta {
        provides temperatures, threshold_violations, in_range_temperatures
        shares temperatures, threshold_violations, in_range_temperatures
    }

    global {
        temperatures = function() {
            ent:temperatures
        }

        threshold_violations = function() {
            ent:threshold_violations
        }

        in_range_temperatures = function() {
            ent:temperatures.difference(ent:threshold_violations)
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading

        pre {
            temperature_map = {
                "temperature": event:attrs{"temperature"},
                "timestamp": event:attrs{"timestamp"}
            }
        }

        always {
            ent:temperatures := ent:temperatures.defaultsTo([]).append(temperature_map)
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation

        pre {
            temperature_map = {
                "temperature": event:attrs{"temperature"},
                "timestamp": event:attrs{"timestamp"}
            }
        }

        always {
            ent:threshold_violations := ent:threshold_violations.defaultsTo([]).append(temperature_map)
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset

        always {
            clear ent:temperatures
            clear ent:threshold_violations
        }
    }

    rule report_requested {
        select when sensor report_start

        pre {
            rci = event:attrs{"rci"}
            agg_Tx = event:attrs{"Rx"}
            my_Rx = event:attrs{"Tx"}
        }
        
        event:send({ 
            "eci": agg_Tx, 
            "eid": "report",
            "domain": "manager", 
            "type": "report_collect",
            "attrs": {
                "rci": rci,
                "Rx": my_Rx,
                "temperature": temperatures().head()
            }
        })
    }
}