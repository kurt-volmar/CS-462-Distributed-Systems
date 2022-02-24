
ruleset sensor_profile {

    meta {
        provides sensor_profile, threshold
        shares sensor_profile, threshold

        use module io.picolabs.wrangler alias wrangler
    }
    
    global {
        sensor_profile = function() {
            {
                "name": ent:name.defaultsTo("Sensor"),
                "threshold": ent:threshold.defaultsTo(79),
                "phone": ent:phone.defaultsTo("801-549-7921")
            }
        }

        threshold = function() {
            sensor_profile(){"threshold"}
        }
    }

    rule update_profile {
        select when sensor profile_updated

        pre {
            name = event:attrs{"name"}
            threshold = event:attrs{"threshold"}
            phone = event:attrs{"phone"}
        }

        always {
            ent:name := name
            ent:threshold := threshold
            ent:phone := phone
        }
    }

    rule initialize_profile {
        select when wrangler ruleset_installed
            where event:attrs{"rid"}.match(re#sensor_profile#)

        event:send({ 
            "eci": wrangler:parent_eci(), 
            "eid": "sensor-ready",
            "domain": "sensor", 
            "type": "rulesets_installed",
            "attrs": wrangler:myself()
        })
    }
}