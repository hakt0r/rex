###
  XMPP module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

xmpp = require 'node-xmpp'

module.exports =

  defaults :
    jid            : "radio@ulzq.de"
    password       : "r4d10"
    xmpp_server    : "ulzq.de"
    room_jid       : "ulzquorum@conf.ulzq.de"
    room_nick      : "rex"
    room_passwd    : ""
    blurb          : false

  init : ( config )->
    ## Load configuration
    { jid,password,xmpp_server,room_jid,room_nick,room_passwd } = config
    subscribers = @config.core.user.subscribers
    room_jid_nick = "#{room_jid}/#{room_nick}"

    ## get a new connection
    @api.Xmpp = Xmpp = new xmpp.Client
      jid: jid + '/bot'
      password: password
      host: xmpp_server || null
    .on 'error', (e) -> console.log e

    ## Incoming connections
    Xmpp.conn = {}
    Xmpp.conn.cache = {}

    ## optional connection tiomout (TODO: OTR+++)
    if config.timeout
      Xmpp.conn.timeout = setInterval () =>
        to = Date.now() / 1000 - 10 # 60 * 10
        for jid, conn of Xmpp.conn.cache
          if conn.lastContact < to
            if conn.finalize?
              unless conn.finalize.call(conn)
                # @debug "not dropping #{jid}"
                conn.lastContact = Date.now() / 1000
                continue
            @debug "dropping #{jid}"
            conn.reply "Terminating your session, bye!"
            delete Xmpp.conn.cache[jid]
      , 10000

    Xmpp.conn.first_message = (message,stanza) =>
      from = stanza.attrs.from
      _reply = (data) => Xmpp.send_to(from, data)
      Xmpp.conn.cache[from] = handle =
        lastContact : Date.now() / 1000
        mode : null
        user : null
        finalize : null
        public_reply : (data) => Xmpp.send_groupchat(data)
        private_reply : _reply
        reply : _reply
      return handle

    Xmpp.conn.message = (message,stanza) =>
      handle = Xmpp.conn.cache[stanza.attrs.from]
      handle = Xmpp.conn.first_message(message,stanza) unless handle?
      return Xmpp.handle_message(message, stanza, handle)
    
    Xmpp.handle_message = (message,stanza,handle) =>
      try
        console.log message
        messages = message.toString().trim().split("\n")
        for message in messages
          if handle.mode isnt null and message.substr(0,5) isnt "!mode"
            message = handle.mode + ' ' + message
          continue unless message.length > 0
          request =
            handle  : handle
            message : stanza
            from    : stanza.attrs.from
            type    : stanza.attrs.type
            to      : stanza.attrs.to
            body    : message
            public_reply  : handle.public_reply
            private_reply : handle.private_reply
            reply         : handle.reply
            message       : handle.reply # TODO: who still uses this?
          @api.Command.exec request, message
      catch e
        console.log "Malicious message or handler:", stanza, e

    ## message formatters
    Xmpp.format = 
      news   : (m)-> "*NEWS* (http://q.ulzq.de/#{m.id}) #{m.title.substr(0,128)}~"
      meta   : (m)-> "*RADIO* #{m.title} - #{m.artist} (#{m.source})"
      debug  : (m)-> "*DEBUG* #{JSON.stringify(m)}"
      studio : (m)-> "*STUDIO* #{JSON.stringify(m)}"
      log    : (m)-> return "*#{k.toUpperCase()}*  #{v}" for k,v of m

    ## implement core outgoing messages
    @on "sendMessage", (message) =>
      for group, msg of message
        return unless Xmpp.format[group]?
        m = Xmpp.format[group].call(null,msg)
        if config.blurb == true       
          Xmpp.send_groupchat(m)
        if subscribers[group]?
          Xmpp.send_to(Object.keys(subscribers[group]),m)

    ## message sending subapi
    Xmpp.send_to = (jids, message) =>
      # @log "to ", #{jids}, " message"
      jids = [jids] if typeof jids is "string"
      return if jids.length < 1
      for key, jid of jids
        Xmpp.send new xmpp.Element("message",
         to: jid
         type: "chat"
        ).c("body").t(message)

    Xmpp.send_groupchat = (message) =>
      Xmpp.send new xmpp.Element("message",
       to: room_jid
       type: "groupchat"
      ).c("body").t(message)

    Xmpp.reply = (stanza,data) =>
      params = {}
      if stanza.attrs.type == "groupchat"
        params.to = room_jid
        params.type = "groupchat"
      else
        params.to = stanza.attrs.from
        params.type = "chat"
      Xmpp.send new xmpp.Element("message", params).c("body").t(data)

    ## xmpp event handlers
    Xmpp.on 'online', () =>
      @log "[online]"
      # set ourselves as online
      Xmpp.send(new xmpp.Element('presence',{}).c('show').t('chat'))
      # join room (and request no chat history)
      el = new xmpp.Element('presence', { to: room_jid_nick });
      x = el.c('x', { xmlns: 'http://jabber.org/protocol/muc' });
      x.c('history', { maxstanzas: 0, seconds: 1});
      x.c('password').t(room_passwd) if room_passwd != ""
      Xmpp.send x

    Xmpp.on 'stanza', (stanza) =>
      # return console.log stanza.toString() if stanza.is('iq') # iq logging
      return console.log('[error] ' + stanza) if stanza.attrs.type is 'error' # always log error stanzas
      return if !stanza.is('message') || !stanza.attrs.type == 'groupchat'    # ignore everything that isn't a room message
      return if stanza.attrs.from == room_jid_nick                            # ignore messages we sent
      body = stanza.getChild('body')
      return if !body                                                         # message without body is probably a topic change
      message = body.getText()
      Xmpp.conn.message(message,stanza)

    @new_command
      cmd  : '!invite'
      admin : yes
      args : true
      fnc  : (request,args) =>
        return request.reply "invite whom" unless args.length > 0
        to = args.shift()
        m = new xmpp.Element("message",{from: jid,to: room_jid}).
          c("x",{xmlns:"http://jabber.org/protocol/muc#user"}).
          c("invite",{to:to}).
          c("reason").
          t("You were invited to #{room_jid} by #{request.from.split('/').pop()}")
        Xmpp.send m

    @new_command
      cmd  : '!own'
      admin : yes
      args : true
      fnc  : (request,args) =>
        whom = args.shift() if args.length > 0
        whom = request.from unless whom?
        m = new xmpp.Element("iq",{id:"admin1",from: jid,to: room_jid,type:"set"}).
          c("query",{xmlns:"http://jabber.org/protocol/muc#admin"}).
          c("item",{affiliation:"owner",jid:whom}).
          c("reason").t("roxbot likes you")
        console.log m.tree().toString()
        Xmpp.send m

    @new_command
      cmd  : '!disown'
      admin : yes
      args : true
      fnc  : (request,args) =>
        whom = args.shift() if args.length > 0
        whom = request.from unless whom?
        m = new xmpp.Element("iq",{id:"admin1",from: jid,to: room_jid,type:"set"}).
          c("query",{xmlns:"http://jabber.org/protocol/muc#admin"}).
          c("item",{affiliation:"none",jid:whom}).
          c("reason").t("#{request.from} hates you")
        console.log m.tree().toString()
        Xmpp.send m

    @new_command
      cmd  : '!mode'
      args : true
      fnc  : (request,args) =>
        return unless request.handle?
        if args[0]?
          request.handle.mode = "!#{args[0]}"
        else request.handle.mode = null
        request.reply "mode: #{request.handle.mode}"

    # @depend "xmpp/otr_slow"
    @depend "xmpp/otr_fast"