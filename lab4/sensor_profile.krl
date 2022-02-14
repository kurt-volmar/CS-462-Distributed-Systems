
ruleset sensor_profile {

    meta {
        provides sensor_profile, threshold
        shares sensor_profile, threshold
    }
    
    global {
        sensor_profile = function() {
            {
                "name": "Kurt's Sensor",
                "location": "Living Room",
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
            threshold = event:attrs{"threshold"}
            phone = event:attrs{"phone"}
        }

        always {
            ent:threshold := threshold
            ent:phone := phone
        }
    }
}