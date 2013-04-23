###
  Main module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

# Global dependencies
events        = require 'events'
child_process = require 'child_process'
fs            = require 'fs'
util          = require 'util'
net           = require 'net'
crypto        = require 'crypto'
request       = require 'request'
iconv         = require 'iconv'

# Decouple classes
Iconv = iconv.Iconv
EventEmitter = events.EventEmitter

# Core functions
setInt = (int,fn)-> return setInterval fn, int
sha512 = (data)-> crypto.createHash('sha512').update(data).digest("hex")
json = (rest...)->
  r = {}
  if rest?
    i = 0
    while i < rest.length
      r[rest[i]] = rest[i+1]; i+=2
  return r

# Some string extensions
String::split_path = -> return this.split('/')
String::basename = -> return this.split('/').pop()
String::dirname  = (i=1)->
  r = this.split '/'
  r.pop() for i in [0...i+2];
  return r.join "/"
Array::isArray = true

PREFIX = __filename.dirname(2) # assume bot dir is one above

# The allmighty Bot Class
class Bot extends EventEmitter

  @cli : (opts={})->
    unless process.argv.length > 2
      Bot = new Bot
    else for key, arg of process.argv
      cli = gui = null
      switch arg
        when "-i", "--interactive"
          CLI = require "./mod/core/cli"
          cli = new CLI -> return new Bot

  api :
  # node modules
    fs : fs
    util: util
    net : net
    iconv : iconv
    crypto : crypto
    request : request
    child_process : child_process
  # functions
    setInt : setInt
    sha512 : sha512
    json : json
  modules     : [ 'core/command', 'core/user' ]
  commands    : {}
  json        : json

  constructor : (opts={}) ->
    _boot = =>
      @base_commands() # add basic commands
      _init = (config) =>
        for module, childs of config
          if config.isArray?
            @load_module childs
          else
            @load_module module
            _init childs if childs? and typeof childs is "object"
      mods = @config.modules
      mods.push m for m in modules if modules?
      _init mods # load modules

    { @project, @project_lib, @config_path, @config_file,
      @bootstrap, modules } = opts

    @project_mode =
      unless @project?
        @project = "rex"
        @project_lib = PREFIX
        no
      else yes
    @config_path = "#{PREFIX}/etc"                   unless @config_path?
    @config_file = "#{PREFIX}/etc/roxbot.local.json" unless @config_file?
    @PREFIX = PREFIX
    @api.Bot = @

    if fs.existsSync @config_file
      @reload()
      @load_module mod for mod in @modules  # load core modules
      _boot()
    else if @bootstrap?
      console.log "First-run init for #{@project}."
      @bootstrap (config) =>
        @config = config if config? # write bootstrap config
        @load_module mod for mod in @modules  # load core modules
        @api.User.register(config.admin.name,config.admin.pass)
        @api.User.addToGroup(config.admin.name,'admin')
        delete config.admin
        @save(); @reload() # refresh config to be sure
        _boot()
    else
      console.log "Loading defaults."
      @load_module mod for mod in @modules  # load core modules
      @config = { modules : [ "xmpp", "feed" ] }
      _boot()
      @save()

  # Log & Message functions
  message : (msg) => @emit("sendMessage", msg)
  log     : (msg) => @message {log:{bot:msg}}
  debug   : (msg) => @message {debug:{bot:msg}}

  # Config handling
  save : => fs.writeFileSync(@config_file,JSON.stringify(@config))

  reload : =>
    if fs.existsSync @config_file
      try @config = JSON.parse(fs.readFileSync(@config_file))
      catch e
        console.error "Error reading existing config file. #{@config_file}", e
        process.exit(1)
    else
      console.error "No config file found #{@config_file}"
      process.exit(1)

  _set_config : (c,a,v) ->
    search = a.shift()
    k = c[search] if c[search]?
    if a.length > 0
      k = c[search] = {} unless k?
      return @_set_config k,a,v
    c[search] = v

  _find_config : (c,a) ->
    search = a.shift()
    k = c[search] if c[search]?
    return undefined unless k?
    return @_find_config k,a if a.length > 0
    return k

  # Module handling
  depend : (name) ->
    @load_module name if @modules.indexOf(name) < 0

  load_module : (name) ->
    console.log (new Error).stack if name is "0"
    console.log "load_module", name
    _load = (name) ->
      n = require.resolve(name)
      delete require.cache[n] if n? and require.cache[n]
      return require(name)
    canidates = [
      "#{PREFIX}/mod/#{name}.coffee",
      "#{PREFIX}/mod/#{name}/#{name.basename()}.coffee" ]
    if @project_mode
      canidates = canidates.concat [
        "#{@project_lib}/#{name}.coffee",
        "#{@project_lib}/#{name}/#{name.basename()}.coffee" ]
    mod = _load f for f in canidates when fs.existsSync(f) 
    if mod?
      config = @_find_config @config, name.split_path() unless config?
      if typeof mod is "function" then mod = mod.call(this,config)
      else
        if !config? and mod.defaults?
          if typeof mod.defaults is "function"
            config = mod.defaults.call(this)
          else config = mod.defaults
          @_set_config @config, name.split_path(), config if config?
        if mod.libs?
          if mod.libs.isArray?
            for lib in mod.libs
              if typeof lib is "string"
                @api[lib] =      _load lib unless @api[lib]?
              else @api[alias] = _load lic for alias, lic of lib      when not @api[lic]?
          else @api[alias] =     _load lib for alias, lib of mod.libs when not @api[alias]?
        @depend dep for dep in mod.deps if mod.deps?
        mod.init.call @, config if mod.init?
      @modules.push name if @modules.indexOf(name) < 0
      return @modules[name]
    else
      console.log "Module not found: #{name}\n", canidates.join()
      return false

  # Request handling
  get_name : (request) =>
    if request.from?
      request.from.split('/').pop()
    else false

  # Command shortcut and base comands
  new_command : (opts={}) -> new @api.Command @, opts
  base_commands : ->
    return
    @new_command
      cmd   : "!bot"
      admin : yes
      args  : on
      fncs  : 
        modules : (request, args) =>
          r = ( k for k,v of @commands )
          request.reply @modules.join(",")
        enmod : (request, args) =>
          @load_module m for m in args
          request.reply "loaded #{@modules.join(",")}"
        fake : (request, args) =>
          try
            message = JSON.parse(message.substr(5))
            @message message
          catch e
            request.reply "FAIL: #{message}\n#{e}"
        js : (request, args) =>
          try
            Bot = _this
            r = request.reply
            i = (a) => request.reply @util.inspect a
            code = args.join(' ')
            code = @COFFEE.compile code, { bare : on }
            eval code
          catch e
            request.reply "ERROR: #{e}\n#{code.trim()}"
        groups : (request) =>
          user = @get_name(request)
          groups = (group for group, members of @User.groups when members.indexOf(user) isnt -1)
          request.reply "your groups, #{user}: #{groups.join(', ')}"
        admins : (request, message) => # TODO: move
          r = ( k for k,v of @api.User.aclgrp['admin'] )
          request.reply r.join(",")

    @new_command
      cmd   : "!user"
      login : on
      args  : on
      fncs  : 
        passwd : (request, args) =>
          user = @get_name(request)
          return request.reply "ERROR: #{user} does not exist" unless @config.user.accounts[user]?
          @config.user.accounts[user].pass = sha512(args[0])
          request.reply "SUCCESS: passwor changed for #{user}"
        sub : (request, args) =>
          group = args[0]
          @User.subscribers[group] = {} unless @User.subscribers[group]?
          @User.subscribers[group][request.from] = sub = {}
          request.reply "Subscribed #{request.from} for #{group}"
        unsub : (request, args) =>
          group = args[0]
          if @User.subscribers[group]? and @User.subscribers[group][request.from]?
            delete @User.subscribers[group][request.from]
          request.reply "Unsubscribed #{request.from} for #{group}"

    @new_command
      cmd  : '!login'
      args : yes
      fnc  : (request, args) =>
        user = @get_name(request)
        user = args.shift() if @api.User.exists args[0]
        pass = args.join(" ").trim()
        @log "*login* #{user}"
        if @api.User.login({user:user,pass_plain:pass,request:request})
          request.reply "OK #{user}"
        else request.reply "FAIL (#{user}) #{request.from}"

    child_process.exec "git reflog | awk '{if(!l++)f=$1}END{printf \"v%i @%s\",l,f}'", (e,o) =>
      @version = "rex the rtv roxbot (#{o.trim()})"
      @new_command cmd : "!version", fnc : (request) => request.reply @version

process.on 'uncaughtException', (err) -> console.error err
module.exports = Bot