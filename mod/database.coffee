###
  Database module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  libs : [ 'jugglingdb' ]
  init : ->
    { PREFIX } = this
    { jugglingdb } = @api
    @api.database = new jugglingdb.Schema "sqlite3",
      database: "#{PREFIX}/etc/roxbot.db"