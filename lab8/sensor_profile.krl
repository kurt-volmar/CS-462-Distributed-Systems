
ruleset sensor_profile {

    meta {
        provides sensor_profile, threshold
        shares sensor_profile, threshold

        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }
    
    global {
        sensor_profile = function() {
            {
                "name": wrangler:myself(){"name"},
                "threshold": ent:threshold.defaultsTo(79),
                "phone": ent:phone.defaultsTo("801-549-7922")
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

    rule parent_notify_ruleset_installed {
        select when wrangler ruleset_installed
            where event:attrs{"rid"}.match(re#sensor_profile#)

        event:send({ 
            "domain": "sensor", 
            "type": "rulesets_installed",
            "eci": wrangler:parent_eci(), 
            "eid": "sensor-ready",
            "attrs": {
                "name": wrangler:myself(){"name"},
                "eci": wrangler:myself(){"eci"},
                "wellKnown_eci": subs:wellKnown_Rx(){"id"}
            }
        })
    }

    rule approve_manager_subs {
        select when wrangler inbound_pending_subscription_added
            where event:attrs{"Tx_role"}.match(re#manager#)

        always {
            raise wrangler event "pending_subscription_approval" attributes event:attrs.put("name", wrangler:myself(){"name"})
        }
    }

    rule threshold_violation {
        select when wovyn threshold_violation
            foreach subs:established() setting (sub)

        pre {
            temperature = event:attrs{"temperature"}
            profile = sensor_profile()
            sub_Tx = sub{"Tx"}.klog("SUB TX:")
        }

        event:send({ 
            "domain": "sensor", 
            "type": "threshold_violation",
            "eci": sub_Tx, 
            "eid": "threshold-violation",
            "attrs": {
                "temperature": temperature,
                "threshold": profile{"threshold"},
                "sensor_name": profile{"name"}
            }
        })
    }
}