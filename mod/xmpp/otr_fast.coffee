###
  XMPP module - part of the rex project
  - otr_fast  - Native LibOTR OTR-binding
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  libs : { OTR : 'otr3' }
  init : ->
    { PREFIX } = this
    { OTR, Xmpp, User } = @api
    config = @config.xmpp
    config_user = @config.core.user

    OTR.byJID = {}

    on_otr_init = =>
      # extend Xmpp.send_to
      _send_to = Xmpp.send_to
      Xmpp.send_to = (jids, message) =>
        jids = [jids] if typeof jids is "string"
        return if jids.length < 1
        notr_jids = []
        for key, jid of jids
          if OTR.byJID[jid]? then OTR.byJID[jid].otr.ses.send message
          else notr_jids.push jid
        _send_to notr_jids, message

      # extend Xmpp.conn.first_message
      _first_message = Xmpp.conn.first_message
      Xmpp.conn.first_message = (message,stanza) =>
        from = stanza.attrs.from
        nick = from.split('/').pop()
        handle = _first_message(message,stanza)
        # start/enable otr if chat type message and user exists
        if stanza.attrs.type is "chat" and config_user.accounts[nick]?
          options =
            fragment_size: 140
            send_interval: 200
            debug:         off,
          stanza = {attrs:{from:from,type:"chat",type:"chat"}}
          handle.reply = (data) => handle.otr.ses.send(data)
          handle.otr = {}
          handle.otr.ctx = ctx = user.ConnContext(config.jid, "xmpp", from)
          handle.otr.ses = ses = new OTR.Session user, ctx,
            policy: OTR.POLICY("ALWAYS")         # optional policy
            MTU: 5000                            # optional
            secret: config_user.accounts[nick].otrsecret # secret
          ses.on "message", (msg,encrypted) => Xmpp.handle_message(msg, stanza, handle)
          ses.on "inject_message", (msg) => _send_to(from, msg)
          ses.on "smp_complete", =>
            user.writeFingerprints()
            User.login {user:nick,keyauth:yes} if ses.isAuthenticated()
          ses.on "smp_request", => ses.respond_smp()
          ses.on "gone_secure", =>
            if ses.isAuthenticated()
              result = User.login user : nick, keyauth : yes, request : { from : from, fake : yes }
          OTR.byJID[from] = handle
        return handle

      ## completely replace Xmpp.conn.message
      Xmpp.conn.message = (message,stanza) =>
        handle = Xmpp.conn.cache[stanza.attrs.from]
        handle = Xmpp.conn.first_message(message,stanza) unless handle?
        return handle.otr.ses.recv(message) if handle.otr? and handle.otr.ses? and stanza.attrs.type isnt "groupchat"
        return Xmpp.handle_message(message, stanza, handle) # groupchat messages are never encrypted (hmm,...:)

      @new_command
        cmd  : '!user.otrpass'
        args : yes
        fnc  : (request,args) =>
          from = request.from
          nick = from.split('/').pop()
          return request.reply "ERROR: OTR FAIL"               unless request.handle.otr.ses?
          return request.reply "ERROR: not encrypted, stupid!" unless request.handle.otr.ses.isEncrypted()
          return request.reply "ERROR: wrong user #{nick}"     unless config_user.accounts[nick]?
          return request.reply "ERROR: wrong user password"    unless User.login(user:nick,pass_plain:args[0])
          config_user.accounts[nick].otrpass = args[1]
          @save(); request.reply "DONE: otr secret changed"

    ## load otr private key / initialize account
    Xmpp.otr_user = user = new OTR.User
      keys: "#{@config_path}/roxbot.keys" #path to OTR keys file (required)
      fingerprints: "#{@config_path}/roxbot.fp" #path to fingerprints file (required)

    if user.accounts().length < 1
      console.log "OTR: Generating Key"
      user.generateKey config.jid, "xmpp", (err) ->
        if err then console.log "something went wrong!", err.message
        else
          console.log "OTR: Generated Key Successfully"
          user.writeFingerprints()
          userstate = user.accounts().shift()
          on_otr_init() 
    else
      userstate = user.accounts().shift()
      on_otr_init()