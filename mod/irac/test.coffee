IRAC = require "./irac"
CLI  = require "./cli"

a = new IRAC "anx",
  ready : ->
    @join
      name : "global.e"

b = new IRAC "xol",
  udp_port : 4322
  ready : ->
    setTimeout =>
        @connect
          address : "127.0.0.1"
          port : 4321
        setTimeout =>
          @join
            name : "global.e"
        , 100
        setTimeout =>
          @message "global.e", "tstor"
        , 200
      , 1000

g = new CLI(b)