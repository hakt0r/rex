CLI  = require "../cli"
IRAC = require "./irac"

COLOR_USER = 6
COLOR_SCOPE = 7
COLOR_CHAT = 5
COLOR_MENTION = 4
COLOR_JOIN = 6
COLOR_PART = 7

class IracCLI extends CLI
  irac : null
  scope : "global.e"
  constructor : (@irac) ->
    super()
    @irac.on "message", (m)=> @out.chat m.peer.user, m.message, COLOR_USER, COLOR_CHAT
  exec : (c) =>
    @historyExec c
    switch (cmd = ((args = c.split(" ")).shift()))
      when "/op"
        @irac.vote_op @scope, args[0]
      when "x"
        try
          irac = ir = @irac
          console.log eval c.substr(2)
        catch e
          console.log e.toString()
      else @irac.message(@scope,c)
  prompt : ->
    @in.print "["
    @in.attron nc.colorPair COLOR_USER
    @in.print @irac.name
    @in.attroff nc.colorPair COLOR_USER
    @in.print ":"
    @in.attron nc.colorPair COLOR_SCOPE
    @in.print @scope
    @in.attroff nc.colorPair COLOR_SCOPE
    @in.print "] "
    @promptlen = @in.curx