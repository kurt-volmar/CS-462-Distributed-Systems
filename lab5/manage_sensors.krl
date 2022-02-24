ruleset manage_sensors {
    meta {
        shares sensors, all_temperatures

        use module io.picolabs.wrangler alias wrangler
    }

    global {
        sensors = function() {
            ent:children.defaultsTo({})
        }

        all_temperatures = function() {
            sensors().map(function(v,k) {
                wrangler:picoQuery(v, "temperature_store", "temperatures", {})
            })
        }

        default_threshold = 78
        default_number = "801-549-7921"
    }

    rule new_sensor {
        select when sensor new
        pre {
            name = event:attrs{"name"}
            exists = sensors() >< name
        }

        always {
            raise wrangler event "new_child_request"
                attributes{"name": name}
                if exists == false
        }
    }

    rule child_initialized {
        select when wrangler child_initialized

        pre {
            name = event:attrs{"name"}
            eci = event:attrs{"eci"}
        }

        always {
            ent:children := ent:children.defaultsTo({}).put(name, eci)
            raise child_rulesets event "install" attributes {"eci": eci}
        }
    }

    rule initialize_state {
        select when sensor rulesets_installed

        pre {
            child_name = event:attrs{"name"}
            child_eci = event:attrs{"eci"}
        }

        event:send({ 
            "eci": child_eci, 
            "eid": "initialize_sensor",
            "domain": "sensor", 
            "type": "profile_updated",
            "attrs": {
                "name": child_name,
                "threshold": default_threshold,
                "phone": default_number
            }
        })
      }

    rule remove_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attrs{"name"}
            eci = sensors(){name}
        }

        always {            
            ent:children := sensors().delete(name)
            raise wrangler event "child_deletion_request"
                attributes{"eci": eci}
        }
    }

}