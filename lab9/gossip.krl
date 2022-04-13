
ruleset gossip {

    meta {
        provides schedules, messages, get_seen, sensor_to_sub, should_process, violation_counter
        shares schedules, messages, get_seen, sensor_to_sub, should_process, violation_counter

        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }

    global {
        schedules = function() {
            schedule:list()
        }

        name = wrangler:myself(){"name"}

        messages = function() {
            return ent:messages.defaultsTo({})
        }

        get_seen = function() {
            return ent:seen.defaultsTo({})
        }

        sequence_number = function() {
            ent:sequence_number.defaultsTo(0)
        }

        extract_message_sequence_number = function(message_id) {
            message_id.extract(re#:([0-9]*)#)[0].as("Number")
        }

        sub_to_sensor = function() {
            ent:sub_to_sensor.defaultsTo({})
        }

        sensor_to_sub = function() {
            ent:sensor_to_sub.defaultsTo({})
        }

        get_peer_shell = function(seen_map_str, sensor, peer_map_str) {
            get_peer(seen_map_str.decode(), sensor, peer_map_str.decode())
        }

        get_peer = function(seen_map, sensor, peer_map) {
            peer_diffs = peer_map.klog("PEER_MAP").map(function(v,k){
                peer_diff(seen_map{sensor}, seen_map{k}).klog("PEER_DIFF")
            })
            
            max_diff = peer_diffs
                .values()
                .sort("numeric")
                .reverse()
                .head()

            peers = peer_diffs
                .filter(function(v,k){v == max_diff})

            rand_n = peers.length() == 0 => 0 | peers.length() - 1 

            peer = peers.keys()
                 .get(random:integer(rand_n))

            peer.klog("PEER")


        }

        max = function(a, b) {
            a >= b => a | b
        }

        peer_diff = function(left, right) {
            l = left.typeof() == "String" => left.decode() | left
            r = right.typeof() == "String" => right.decode() | right

            l.map(function(v,k){
                l_n = l{k}.isnull() => -1 | l{k}
                r_n = r{k}.isnull() => -1 | r{k}
                diff = l_n - r_n
                max(0, diff).klog("MAX")
            })
            .values()
            .reduce(function(a,b){a + b})
        }

        prepare_message = function(peer_name, message_type) {
            (message_type == "rumor" => prepare_rumor(peer_name) | prepare_seen(peer_name)).klog("MESSAGE RET")
        }

        prepare_rumor = function(peer_name) {
            my_seen = get_seen(){name}.klog("MY_SEEN")
            peer_seen = get_seen(){peer_name}.klog("PEER_SEEN")
            all_keys = my_seen.keys().union(peer_seen.keys()).klog("ALL_KEYS")
            need_updates = all_keys.filter(function(x){
                my_seen_x = my_seen{x}.isnull() => -1 | my_seen{x}
                peer_seen_x = peer_seen{x}.isnull() => -1 | peer_seen{x}
                my_seen_x.klog("MY_SEEN_X") > peer_seen_x.klog("PEER_SEEN_X")
            }).difference([peer_name]).klog("NEED_UPDATES")
            n_need_updates = need_updates.length().klog("N_NEEDS_UPDATES")
            sensor_to_update = need_updates{random:integer(n_need_updates => n_need_updates-1 | 0).klog("RAND")}.klog("SENSOR_TO_UPDATE")
            sequence_min = ((peer_seen{sensor_to_update}.isnull() => 0 | peer_seen{sensor_to_update} + 1)).klog("SEQ_MIN")
            sequence_max = my_seen{sensor_to_update}.klog("SEQ_MAX") || 0
            sequence_diff = sequence_max - sequence_min
            sequence_range = sequence_diff > 20 => range(sequence_min, sequence_min + 20) | range(sequence_min, sequence_max)
            many_messages = sequence_range.klog("RANGE").map(
                function(x){
                    message_id = sensor_to_update + ":" + x
                    messages(){[sensor_to_update, message_id.klog("MESSAGE_ID")]}.klog("MESSAGE")
                }
            )
            many_messages.filter(function(x){x.isnull() == false}).klog("MESSAGES")
        }

        prepare_seen = function(peer_name) {
            get_seen()
        }

        merge_shell = function(left, right) {
            merge_seen(left.decode(), right.decode())
        }

        merge_seen = function(left, right) {
            common = right.klog("RIGHT").keys().union(left.klog("LEFT").keys())
            diff = right.keys().difference(left.keys())

            common_map = common
                .map(function(x){ {}.put(x, null) })
                .collect(function(x){x.keys().head()})
                .map(function(v,k){
                    merge_seen_inside(left{k}, right{k})
                })

            diff_map = diff
                .map(function(x){ {}.put(x, null) })
                .collect(function(x){x.keys().head()})
                .map(function(v,k){
                    right{k}
                })
            
            left.put(common_map.put(diff_map))
            .klog("MERGED")
        }

        merge_seen_inside = function(left, right) {
            common = right.keys().union(left.keys())
            diff = right.keys().difference(left.keys())
            
            common_map = common
                .map(function(x){ {}.put(x, null) })
                .collect(function(x){x.keys().head()})
                .map(function(v,k){
                    left_val = left{k}.isnull() => -1 | left{k}
                    right_val = right{k}.isnull() => -1 | right{k}
                    max(left_val, right_val)                        
                })

            diff_map = diff
                .map(function(x){ {}.put(x, null) })
                .collect(function(x){x.keys().head()})
                .map(function(v,k){
                    right{k}
                })
            
            left.put(common_map.put(diff_map))
        }

        should_process = function() {
            ent:should_process.defaultsTo(true)
        }

        in_violation = function() {
            ent:in_violation.defaultsTo(false)
        }

        violation_counter = function() {
            ent:violation_counter.defaultsTo(0)
        }

        sum_violation_messages = function(messages) {
            messages
                .keys()
                .map(function(key){
                    messages{key}.values()
                })
                .reduce(function(a, b){
                    a.union(b)
                }).klog("REDUCE")
                .map(function(x){x{"increment"}})
                .reduce(function(a,b){a+b}).klog("YARGY")

            // sum = messages
            //     .map(function(v,k){v.values()}).klog("MAPa")
            //     .collect(function(x){x.values()}).klog("COLLECTa")
            // sum
        //         .filter(function(x){x{"type"} == "threshold_violation_status"}).klog("FILTER")
        //         .map(function(x){x{"increment"}}).klog("MAP")
        //         .reduce(function(a,b){a + b}).klog("REDUCE")
        //     sum.isnull().klog("IS_NULL") => 0.klog("ZERO") | sum.klog("RETURN SUM")
        }
    }

    rule start_heartbeat {
        select when gossip start_heartbeat

        pre {
            interval = event:attrs{"interval"} || 1
        }

        always {
            raise gossip event "intro_to_subs"
            schedule gossip event "heartbeat"
                repeat << */#{interval} * * * * * >>  attributes { } setting(id);
        }
    }

    rule stop_heartbeat {
        select when gossip stop_heartbeat

        pre {
            heartbeat_schedule_id = schedule:list()[0]
        }

        schedule:remove(heartbeat_schedule_id)
    }

    rule reset {
        select when gossip reset

        always {
            ent:messages := {}
            ent:seen := {}
            ent:sequence_number := 0
            ent:sub_to_sensor := {}
            ent:sensor_to_sub := {}
        }
    }

    rule sensor_reading {
        select when wovyn new_temperature_reading

        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            is_threshold_violation = event:attrs{"is_threshold_violation"}.as("Boolean").klog("THRESH ORIG")
            // temperature_f = event:attrs{["genericThing", "data", "temperature"]}[0]{"temperatureF"}
        }

        always {
            // Reading message
            increment = (in_violation() == false) && (is_threshold_violation == true) => 1
                        | (in_violation() == true) && (is_threshold_violation == false) => -1
                        | 0
            reading_data = {
                "message_id": name + ":" + sequence_number(),
                "sensor_id": name,
                "temperature": temperature,
                "timestamp": timestamp,
                "increment": increment
            }
            ent:in_violation := is_threshold_violation
            ent:messages := messages().put([name, reading_data{"message_id"}], reading_data)
            ent:seen := get_seen().put([name, name], sequence_number())
            ent:sequence_number := sequence_number() + 1
            // ent:violation_counter := (violation_counter().klog("CURRENT") + increment.klog("INCREMENT")).klog("NEW VAL")
            ent:violation_counter := sum_violation_messages(messages())
            // raise wovyn event "self_threshold_violation" 
            //     attributes event:attrs 
            //     if is_threshold_violation == true
        }
    }

    // rule sensor_violation {
    //     select when wovyn self_threshold_violation

    //     pre {
    //         temperature = event:attrs{"temperature"}
    //         timestamp = event:attrs{"timestamp"}
    //         is_threshold_violation = event:attrs{"is_threshold_violation"}.klog("EVENT THRESH").as("Boolean").klog("THRESH")
    //         // temperature_f = event:attrs{["genericThing", "data", "temperature"]}[0]{"temperatureF"}
    //     }

    //     always {
    //         // increment = (in_violation() == false) && (is_threshold_violation == true) => 1
    //         //             | (in_violation() == true) && (is_threshold_violation == false) => -1
    //         //             | 0
    //         // threshold_violation_data = {
    //         //     "message_id": name + ":" + sequence_number(),
    //         //     "sensor_id": name,
    //         //     "increment": increment,
    //         //     "type": "threshold_violation_status"
    //         // }
    //         // ent:in_violation := is_threshold_violation
    //         // ent:messages := messages().put([name, threshold_violation_data{"message_id"}], threshold_violation_data)
    //         // ent:seen := get_seen().put([name, name], sequence_number())
    //         // ent:sequence_number := sequence_number() + 1
    //         // ent:violation_counter := violation_counter() + increment
    //     }
    // }

    rule heartbeat {
        select when gossip heartbeat

        pre {
            peer = get_peer(get_seen().klog("MY_SEEN_1"), name, sensor_to_sub())
            peer_sub_id = sensor_to_sub(){peer}
            peer_Tx = subs:established().filter(function(x){x{"Id"} == peer_sub_id})[0]{"Tx"}
            message_type = random:integer(1) == 0 => "rumor" | "seen"
            message = prepare_message(peer, message_type)
        }
        
        if message.isnull() == false && message.length() > 0 then
            event:send({ 
                "eci": peer_Tx, 
                "eid": "initialize_sensor",
                "domain": "gossip", 
                "type": message_type.klog("TYPE"),
                "attrs": {
                    // "sub_id": peer_sub_id,
                    "message": message.klog("MESSAGE")
                }
            })

        fired {
            ent:seen := get_seen().klog("PRE-ADD")
            ent:seen := get_seen().put([peer.klog("PEER"), message.head(){"sensor_id"}.klog("SENSOR_ID")], extract_message_sequence_number(message.reverse().head(){"message_id"}).klog("SEQ_NUM")).klog("PUT") 
                if message_type == "rumor" && message.isnull() == false
            ent:seen := get_seen().klog("MY_SEEN_2")
        } 
    }

    rule intro_to_subs {
        select when gossip intro_to_subs
            foreach subs:established() setting(sub)

        event:send({ 
            "eci": sub{"Tx"}, 
            "eid": "initialize_sensor",
            "domain": "gossip", 
            "type": "intro_sensor",
            "attrs": {
                "sub_id": sub{"Id"},
                "sensor_id": name
            }
        })
    }

    rule intro_sensor {
        select when gossip intro_sensor
        pre {
            sub_id = event:attrs{"sub_id"}
            sensor_id = event:attrs{"sensor_id"}
        }

        always {
            ent:sub_to_sensor := sub_to_sensor().put(sub_id, sensor_id)
            ent:sensor_to_sub := sensor_to_sub().put(sensor_id, sub_id)
        }
    }

    rule rumor {
        select when gossip rumor where event:attrs{"message"}.isnull() == false
            foreach event:attrs{"message"} setting(rumor)
                
        pre {
            sensor_id = rumor{"sensor_id"}
            message_id = rumor{"message_id"}
            message_sequence_number = extract_message_sequence_number(message_id)
        }

        

        always {
            // Put in messages map
            ent:messages := messages().put([sensor_id, message_id], rumor) if should_process() == true

            // Record as seen
            ent:seen := get_seen(){[name, sensor_id]}.isnull() => get_seen().put([name, sensor_id], -1) | get_seen() if should_process() == true
            ent:seen := get_seen().klog("MY_SEEN1")
            ent:seen := get_seen(){[name, sensor_id]} == (message_sequence_number - 1) => get_seen().put([name, sensor_id], message_sequence_number) | get_seen() if should_process() == true
            ent:seen := get_seen().klog("MY_SEEN2")

            // Update violation counter
            // ent:violation_counter := violation_counter() + rumor{"increment"} if should_process() == true
            ent:violation_counter := sum_violation_messages(messages()) 
        }
    }

    rule seen {
        select when gossip seen

        pre {
            sensor_seen = event:attrs{"message"}.typeof() == "Map" => event:attrs{"message"} | event:attrs{"message"}.decode()
        }

        always {
            ent:seen := merge_seen(get_seen().klog("MY_SEEN"), sensor_seen.klog("OTHER_SEEN")) if should_process() == true
        }
    }

    rule set_seen {
        select when gossip set_seen 
        always {
            ent:seen := event:attrs{"seen"}
        }
    }

    rule toggle_should_process {
        select when gossip toggle_should_process

        always {
            ent:should_process := should_process() == true => false | true
        }
    }

    rule pseudo_new_temperature_reading {
        select when wovyn pseudo_new_temperature_reading

        pre {
            temperature = event:attrs{"temperature"}
            timestampe = event:attrs{"timestamp"}
            is_threshold_violation = event:attrs{"is_threshold_violation"}
        }

        always {
            raise wovyn event "new_temperature_reading" attributes event:attrs
        }
    }
}