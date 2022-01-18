ruleset twilio_test {
    meta {
        shares test_messages

        use module twilio_sdk alias twilio 
            with
                twilio_account_sid = meta:rulesetConfig{"twilio_account_sid"}
                twilio_auth_token = meta:rulesetConfig{"twilio_auth_token"}
    }

    global {
        test_messages = function(message_sid = null, to = null, from = null, page_size = null, page = null, page_token = null) {
            twilio:messages(message_sid, to, from, page_size, page, page_token)
        }
    }

    rule send_message {
        select when echo hello

        pre {
            body = event:attrs{"body"}
            from = event:attrs{"from"}
            to = event:attrs{"to"}
        }

        twilio:send_message(body, from, to)
    }
}