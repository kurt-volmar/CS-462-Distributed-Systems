ruleset twilio_sdk {
    meta {
        provides messages, get_all, get_one, send_message

        configure using
            twilio_account_sid = ""
            twilio_auth_token = ""
    }

    global {
        twilio_auth = {
            "username": twilio_account_sid,
            "password": twilio_auth_token
        }

        messages = function(message_sid, to, from, page_size, page, page_token) {
            message_sid => get_one(message_sid) | get_all(to, from, page_size, page, page_token)
        }

        get_all = function(to, from, page_size, page, page_token) {
            query_params = {}
                .put(to => {"To": to} | {})
                .put(from => {"From": from} | {})
                .put(page_size => {"PageSize": page_size} | {})
                .put(page => {"Page": page} | {})
                .put(page => {"PageToken": page_token} | {})                

            twilio_get(<<https://api.twilio.com/2010-04-01/Accounts/#{twilio_auth{"username"}}/Messages.json>>, query_params, twilio_auth)
        }

        get_one = function(message_sid) {
            twilio_get(<<https://api.twilio.com/2010-04-01/Accounts/#{twilio_auth{"username"}}/Messages/#{message_sid}.json>>, {}, twilio_auth)
        }

        twilio_get = function(url, qs, auth) {
            http:get(
                url, 
                qs = qs,
                auth = auth
            )
            .get("content")
            .decode()
        }

        send_message = defaction(body, from, to) {
            http:post(
                << https://api.twilio.com/2010-04-01/Accounts/#{twilio_auth{"username"}}/Messages.json >>,
                form = {
                    "Body": body,
                    "From": from,
                    "To": to
                },
                auth = twilio_auth.klog("POST_AUTH")
            ) setting(response)
            return response
        }
    }
}