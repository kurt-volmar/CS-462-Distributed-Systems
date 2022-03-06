
ruleset child_ruleset_installer {
    rule install_child_ruleset {
        select when child_rulesets install

        pre {
            eci = event:attrs{"eci"}
        }

        always {
            raise child_install_ruleset event "wovyn_emulator" attributes {"eci": eci}
            raise child_install_ruleset event "sensor_profile" attributes {"eci": eci}
            raise child_install_ruleset event "wovyn_base" attributes {"eci": eci}
            raise child_install_ruleset event "temperature_store" attributes {"eci": eci}
        }
    }

    rule install_wovyn_emulator {
        select when child_install_ruleset wovyn_emulator 

        pre {
            eci = event:attrs{"eci"}
        }

        event:send({ 
            "eci": eci, 
            "eid": "install-ruleset",
            "domain": "wrangler", 
            "type": "install_ruleset_request",
            "attrs": {
                "absoluteURL": "file:///Users/byu/cs462/lab6/wovyn_emulator.krl",
                "rid": "wovyn_emulator",
                "config": {}
            }
        })
    }

    rule install_sensor_profile {
        select when child_install_ruleset sensor_profile

        pre {
            eci = event:attrs{"eci"}
        }

        event:send({ 
            "eci": eci, 
            "eid": "install-ruleset",
            "domain": "wrangler", 
            "type": "install_ruleset_request",
            "attrs": {
                "absoluteURL": "file:///Users/byu/cs462/lab6/sensor_profile.krl",
                "rid": "sensor_profile",
                "config": {}
            }
        })
    }

    rule install_wovyn_base {
        select when child_install_ruleset wovyn_base

        pre {
            eci = event:attrs{"eci"}
        }

        event:send({ 
            "eci": eci, 
            "eid": "install-ruleset",
            "domain": "wrangler", 
            "type": "install_ruleset_request",
            "attrs": {
                "absoluteURL": "file:///Users/byu/cs462/lab6/wovyn_base.krl",
                "rid": "wovyn_base",
                "config": {}
            }
        })
    }

    rule install_temperature_store {
        select when child_install_ruleset temperature_store

        pre {
            eci = event:attrs{"eci"}
        }

        event:send({ 
            "eci": eci, 
            "eid": "install-ruleset",
            "domain": "wrangler", 
            "type": "install_ruleset_request",
            "attrs": {
                "absoluteURL": "file:///Users/byu/cs462/lab6/temperature_store.krl",
                "rid": "temperature_store",
                "config": {}
            }
        })
    }
}