###
  Web module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  defaults : [ port : 8020 ]
  libs : [ 'express' ]
  init : (config) ->
    { express } = @api
    @api.Web = app = express()
    app.use express.compress()
    app.listen config.port