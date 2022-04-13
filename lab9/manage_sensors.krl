ruleset manage_sensors {
    meta {
        shares children, sensor_subs, all_temperatures
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

        rcis = function() {
            ent:rcis.defaultsTo([])
        }

        gossip_setup_config = {
            "nodes": ["A", "B", "C", "D", "E"],
            "subs": {
                "A": ["B"],
                "B": ["C", "D"],
                "C": ["D"],
                "D": ["E"],
                "E": []
            }
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

    rule create_gossip_cluster_nodes {
        select when gossip_setup create_cluster_nodes
            foreach gossip_setup_config{"nodes"} setting (node)

        always {
            raise sensor event "new" attributes{"name": node}
        }
    }

    rule create_gossip_cluster_subs {
        select when gossip_setup create_cluster_subs
            foreach gossip_setup_config{"nodes"} setting(node)
            foreach gossip_setup_config{["subs", node]} setting(other)

        always {
            raise gossip_setup event "create_sub" attributes {
                "node": node,
                "other": other
            }
        }    
    }

    rule create_gossip_cluster_sub {
        select when gossip_setup create_sub
        pre {
            node = event:attrs{"node"}
            node_eci = children(){[node, "eci"]}
            node_sub_id = children(){[node, "sub_id"]}
            node_sub = sensor_subs().filter(function(x){x{"Id"} == node_sub_id}).klog("node_sub")
            node_Tx = node_sub[0]{"Tx"}.klog("node_Tx")

            other = event:attrs{"other"}
            other_eci = children(){[other, "eci"]}.klog("OTHER_ECI")
            other_wellknown = wrangler:picoQuery(other_eci, "io.picolabs.subscription","wellKnown_Rx"){"id"}.klog("OTHER_WELLKNOWN")
        }

        event:send({ 
            "eci": node_Tx, 
            "eid": "initialize_sensor",
            "domain": "gossip_setup", 
            "type": "peer_sub",
            "attrs": {
                "other_eci": other_wellknown
            }
        })
    }



    rule teardown_gossip_cluster {
        select when gossip_setup teardown_cluster
            foreach gossip_setup_config{"nodes"} setting (node)

        always {
            raise sensor event "unneeded_sensor" attributes{"name": node}
        }
    }
}