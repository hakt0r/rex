CLI  = require "../../lib/cli"

COLOR_USER = 6
COLOR_SCOPE = 7
COLOR_CHAT = 5
COLOR_MENTION = 4
COLOR_JOIN = 6
COLOR_PART = 7
COLOR_EXEC = 3

class RoxCLI extends CLI

  Bot : null
  scope : "roxsh"

  constructor : (onready) ->
    self = this
    @pwd = process.cwd()
    super
      input:
        on_complete : @complete
        on_exec     : @exec
        prompt      : (cmd) ->
          @print "["
          @attron @nc.colorPair COLOR_USER
          @print process.env.USER
          @attroff @nc.colorPair COLOR_USER
          @print ":"
          @attron @nc.colorPair COLOR_SCOPE
          @print self.pwd
          @attroff @nc.colorPair COLOR_SCOPE
          @print "] "
          @promptlen = @curx
    @log = @out.log
    @Bot = onready()
    @Bot.on "message", (m)=> @out.chat m.peer.user, m.message, COLOR_USER, COLOR_CHAT

  scroll : (up) =>
    @out.scroll if up then 1 else -1

  complete : (c) =>
    return false

  exec : (c) =>
    c = c.trim()

    # COULD YOU BE... A BOT COMMAND
    for command, call of @Bot.commands
      if c is command or c.indexOf(command+" ") is 0
        request =
          handle  : @out
          from    : "cli"
          type    : "input"
          to      : "local"
          body    : c
          reply   : (m) => @log c, COLOR_EXEC, m
          message : (m) => @log c, COLOR_EXEC, m
        return call(request, c)

    switch (cmd = ((args = c.split(" ")).shift()))
      when "" then return
      # COULD YOU BE... A CHDIR
      when "cd"
        @pwd = @pwd+"/"+args.join(" ")
        @pwd = @Bot.FS.realpathSync(@pwd)
        console.log "CD to #{@pwd}"
      when "/op"
        @Bot.vote_op @scope, args[0]
      # COULD YOU BE... A DEBUG COMMAND
      when "x","i", "k"
        CLI = _this
        Bot = @Bot
        code = args.join(" ")
        code = Bot.COFFEE.compile code, { bare : on }
        code = "Object.keys(#{code})" if cmd is "k"
        code = "Bot.UT.inspect(#{code})" if cmd is "i"
        try @log code.trim(), COLOR_EXEC, eval code
        catch e
          console.log e.toString()
      else
        # COULD YOU BE... A SHELL COMMAND
        if (pcmd = @is_os_command(cmd))
          args = args.join(" ")
          @Bot.CP.exec(
            "cd #{@pwd}; #{pcmd} #{args}"
            (error,stdout,stderr)=>
              console.error stderr if error
              @log "#{cmd} #{args}".trim(),COLOR_EXEC,"\n"+stdout.trim())
        else @Bot.Xmpp.send_groupchat(c)

  is_os_command : (cmd) ->
    FS = @Bot.FS
    PATH = process.env.PATH.split(":")
    return "#{p}/#{cmd}" for k,p of PATH when FS.existsSync "#{p}/#{cmd}"
    return false

module.exports = RoxCLI