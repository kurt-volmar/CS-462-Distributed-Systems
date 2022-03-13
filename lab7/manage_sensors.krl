ruleset manage_sensors {
    meta {
        shares children, sensor_subs, all_temperatures, reports, latest_reports
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }

    global {
        children = function() {
            ent:children.defaultsTo({})
        }

        sensor_subs = function() {
            subs:established().filter(function(x) {x{"Tx_role"} == "sensor"})
        }

        all_temperatures = function() {
            sensor_subs().map(function(s) {
                {}.put(s{"Tx"}, wrangler:picoQuery(s{"Tx"}, "temperature_store", "temperatures", {}))
            })
        }

        reports = function() {
            ent:reports.defaultsTo({})
        }

        rcis = function() {
            ent:rcis.defaultsTo([])
        }

        latest_reports = function() {
            n = rcis().length() >= 5 => 4 | rcis().length()
            rcis()
                .reverse()
                .slice(n)
                .map(function(x){reports(){x}})
        }

        default_threshold = 78

        default_number = "801-549-7921"
    }

    rule new_sensor {
        select when sensor new

        pre {
            name = event:attrs{"name"}
            exists = children() >< name
        }

        always {
            raise wrangler event "new_child_request" attributes{"name": name}
                if exists == false
        }
    }

    rule child_initialized {
        select when wrangler child_initialized

        pre {
            eci = event:attrs{"eci"}
        }

        always {
            raise child_rulesets event "install" attributes {"eci": eci}
        }
    }

    rule child_rulesets_installed {
        select when sensor rulesets_installed

        pre {
            child_name = event:attrs{"name"}
            child_eci = event:attrs{"eci"}
            child_wellKnown_eci = event:attrs{"wellKnown_eci"}
        }

        always {
            ent:children := ent:children.defaultsTo({}).put([child_name, "eci"], child_eci)
            raise sensor event "initialize_subscription" attributes {"wellKnown_Tx": child_wellKnown_eci}
        }
    }

    rule initialize_subscription {
        select when sensor initialize_subscription
        
        pre {
            sensor_wellKnownTx = event:attrs{"wellKnown_Tx"}
        }

        always {
            raise wrangler event "subscription" attributes {
                "name": "sensor_management",
                "wellKnown_Tx": sensor_wellKnownTx,
                "Rx_role": "manager",
                "Tx_role": "sensor"
            }
        }
    }

    rule child_subscription_added {
        select when wrangler subscription_added

        pre {
            sub_id = event:attr("Id")
            sensor_name = event:attr("name")
            is_child_sensor = children() >< sensor_name
            child_sub = sensor_subs().filter(function(x){x{"Id"} == sub_id})
        }

        always {
            ent:children := is_child_sensor => children().put([sensor_name, "sub_id"], sub_id) | children()
            raise sensor event "set_state" attributes {"child_sub_tx": child_sub[0]{"Tx"}}
                if is_child_sensor
        }
    }

    rule set_sensor_state {
        select when sensor set_state

        pre {
            child_sub_tx = event:attrs{"child_sub_tx"}
        }

        event:send({ 
            "eci": child_sub_tx, 
            "eid": "initialize_sensor",
            "domain": "sensor", 
            "type": "profile_updated",
            "attrs": {
                "threshold": default_threshold,
                "phone": default_number
            }
        })
    }

    rule sensor_threshold_violation {
        select when sensor threshold_violation

        pre {
            sensor_name = event:attrs{"sensor_name"}
            threshold = event:attrs{"threshold"}
            temperature = event:attrs{"temperature"}
        }

        always {
            raise profile event "send_threshold_alert" attributes {
                "sensor_name": sensor_name,
                "threshold": threshold,
                "temperature": temperature
            }
        }
    }

    rule remove_sensor {
        select when sensor unneeded_sensor

        pre {
            child_name = event:attrs{"name"}
            child = children(){child_name}
        }

        always {
            ent:children := children().delete(child_name)
            raise wrangler event "subscription_cancellation" attributes {"Id": child{"sub_id"}}        
            raise wrangler event "child_deletion_request" attributes{"eci": child{"eci"}}
        }
    }

    rule start_report {
        select when manager report_start

        pre {
            rci = random:uuid()
            report = {
                "scattered": sensor_subs().length(),
                "gathered": 0,
                "readings": [],
                "started": time:now()
            }
        }

        always {
            ent:reports := reports().put([rci], report)
            ent:rcis := rcis().append(rci)
            raise manager event "report_start_scatter"
                attributes {"rci": rci}
        }
    }

    rule start_report_scatter {
        select when manager report_start_scatter
            foreach sensor_subs() setting(sensor)

        pre {
            rci = event:attrs{"rci"}
            sensor_Tx = sensor{"Tx"}
            sensor_Rx = sensor{"Rx"}
        }

        event:send({ 
            "eci": sensor_Tx, 
            "eid": "report",
            "domain": "sensor", 
            "type": "report_start",
            "attrs": {
                "rci": rci,
                "Tx": sensor_Tx,
                "Rx": sensor_Rx
            }
        })
    }

    rule aggregate_report {
        select when manager report_collect

        pre {
            rci = event:attrs{"rci"}

            report = reports(){rci}
            readings = report{"readings"}
            scattered = report{"scattered"}
            gathered = report{"gathered"}

            sensor_Tx = event:attrs{"Rx"}
            temperature = event:attrs{"temperature"}
            reading = {"sensor_Tx": sensor_Tx}.put(temperature)
        }
        
        always {
            new_report = report
                .set("gathered", gathered + 1)
                .set("readings", readings.append(reading))
            ent:reports := reports().set(rci, new_report)
        }
    }

    rule clear_reports {
        select when manager reports_clear
        always {
            ent:reports := {}
            ent:rcis := []
        }
    }
}