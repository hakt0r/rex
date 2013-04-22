###
  System module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  libs : [ 'tail' ]
  init : ->
    { tail, message } = @api
    t = new tail "/var/log/liquidsoap/radio.log"
    t.on "line", (line) -> message { log : { radio : line } }