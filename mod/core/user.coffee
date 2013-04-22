###
  User module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

class User
  @usracl : {} # usracl is a temporary construct, feed by login and login ONLY!
  @aclusr : {} # aclusr is a temporary construct, feed by login and login ONLY!
  @aclgrp : {} # aclgrp is a temporary construct, feed by login and login ONLY!

  @groups : {}
  @accounts : {}
  @subscribers : {}

  @init : (config) ->
    { @sha512, @accounts, @groups, @subscribers, @log } = config

  @exists : (name) ->
    console.log "exists?", name, @accounts
    return @accounts[name]?

  @is_admin : (user) -> return @is_authorized user, 'admin'

  @is_authorized : (user,group) ->
    if @aclgrp[group]?
      return true if @aclgrp[group][user]?
      return true if @aclgrp[group][@usracl[user]]?
    @log "*not authorized* #{user} #{group}"
    false

  @login : (opts) ->
    success = no
    success = yes if opts.keyauth? and opts.keyauth is true
    opts.pass = @sha512(@sha512(opts.pass_plain)+(opts.salt = "lol")) if opts.pass_plain?
    success = yes if opts.pass? and @accounts[opts.user]? and opts.pass == @sha512(@accounts[opts.user].pass+opts.salt)
    if success
      @aclusr[opts.user] = {} unless @aclusr[opts.user]?
      if opts.request?
        @aclusr[opts.user][opts.request.from] = yes
        @usracl[opts.request.from] = [opts.user]
      for group, members of @groups
        unless members.indexOf(opts.user) is -1
          @aclgrp[group] = {} unless @aclgrp[group]?
          @aclgrp[group][opts.user] = true
    return success # console.log "LOGIN(#{opts.user})", opts, success, @aclgrp, @aclusr, @usracl

module.exports =
  defaults :
    accounts :
      admin:
        pass: "96185d802496a6bad66bbfed7854537caad8d136a8ff4a24a1ce723dcb5830359be656fdf4eb707f2d75bd6c3b24657c57f1c44abdee4b609f122f07878d4f1e"
    groups : { admin : [ 'admin' ] }
    subscribers : {}
  init : (config) ->
    User.init
      log :         @log
      sha512 :      @api.sha512
      accounts :    config.accounts
      groups :      config.groups
      subscribers : config.subscribers
    @api.User = User