ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    shares hello
  }
   
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
  }
   
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }
   
  rule something {
    select when echo something_else
  }

  rule lab_0 {
    select when echo monkey

    pre {
      name = event:attrs{"name"}.klog("out passed in name: ")
    }
    send_directive("say", {"something": "Hello " + (name || "Monkey")})
  }
}