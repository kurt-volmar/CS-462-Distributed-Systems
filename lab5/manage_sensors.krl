ruleset manage_sensors {
    meta {
        shares sensors
    }

    global {
        sensors = function() {
            ent:children.defaultsTo({})
        }
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

    rule remove_sensor {
        select when sensor remove
        pre {
            name = event:attrs{"name"}
            eci = sensors(){name}
        }

        always {            
            raise wrangler event "child_deletion_request"
                attributes{"eci": eci}
        }
    }

    rule child_initialized {
        select when wrangler child_initialized

        pre {
            name = event:attrs{"name"}
            eci = event:attrs{"eci"}
        }

        always {
            raise child_rulesets event "install" attributes {"eci": eci}
            ent:children := ent:children.defaultsTo({}).put(name, eci)
        }
    }

    rule child_deleted {
        select when wrangler child_deleted
        pre {
            eci = event:attrs{"eci"}.klog("YARGY")
        }

        always {
            ent:children := sensors().filter(function(v, k){v != eci})
        }
    }
}