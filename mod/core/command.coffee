###
  Command module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

class Command
  @byName  : {}
  @isAlias : {}

  @unalias : (alias) ->
    if @isAlias[alias]?
      delete @isAlias[alias]
      delete @byName[alias]

  @alias : (command, alias) ->
    command = @byName[command] if (t = typeof command) is "string" and @byName[command]?
    @byName[alias] = command   if command? and command instanceof Command
    return @isAlias[alias] = yes if @byName[alias]
    console.error "Bad alias: #{alias} -> #{command.cmd}"

  @exec : (request, message) ->
    for command, call of @byName
      if message is command or message.indexOf(command+" ") is 0
        call(request, message); break

  @add :
    public : (fnc) -> return (request, message) ->
      request.reply = request.public_reply if request.type is "groupchat"
      fnc(request, message)
    args : (fnc) -> return (request, message) ->
      m = message.trim().split(" ")
      m.shift()
      a = []; a.push v if v != "" for k,v of m
      m = [m] if typeof m is "string"
      fnc(request, m)
    admin : (fnc, parent) -> return (request, message) ->
      return fnc(request, message) if parent.api.User.is_admin(request.from)
      console.log m = "NOT AUTHORIZED #{request.from}: #{message}"
    switch : (fncs, parent) -> return (request, args) ->
      console.log "switch #{args.join(' ')}", Object.keys fncs
      if fncs[cmd = args.shift()]?
        console.log "call #{cmd} for #{@cmd}"
        fncs[cmd].call parent, request, args
      else if fncs['help']?
        console.log "help for #{@cmd}"
        fncs['help'].call parent, request, args
      else
        request.reply "*Error*: command not found #{cmd} #{args.join(' ')}\n" + 
          "valid arguments: #{Object.keys(fncs).join(' ')}"

  constructor : (parent, opts)->
    opts = parent unless opts? # parent is an optional argument and
    { @cmd, fnc, fncs, @admin, @args, @public, alias } = opts
    @args   = off unless @args?
    @admin  = off unless @admin?
    @public = off unless @public?
    fnc = Command.add.switch fncs, parent, @args = on if fncs? and typeof fncs is "object"
    throw new Error("No callback for #{@cmd}") unless typeof fnc is "function"
    fnc = Command.add.public fnc, parent if @public
    fnc = Command.add.args   fnc, parent if @args
    fnc = Command.add.admin  fnc, parent if @admin
    Command.byName[@cmd] = fnc
    if alias?
      if (t = typeof alias) is "string" then Command.alias @, alias
      else if t is "object" then Command.alias @, v for v in alias

new Command
  cmd : "!help"
  fnc : (request, message) =>
    r = ( k for k,v of Command.byName )
    r.sort()
    request.reply r.join(", ")

module.exports =
  init : -> @api.Command = Command