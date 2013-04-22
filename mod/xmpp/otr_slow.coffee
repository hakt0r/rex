###
  XMPP module - part of the rex project
  - otr_fast  - Pure JS OTR-binding
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  libs : [ 'otr' ]
  init : ->
    config = @config.xmpp
    { otr, Xmpp } = @api
    DSA = otr.DSA
    OTR = otr.OTR

    # load otr private key
    if config.private?
      Xmpp.private_key = DSA.parsePrivate(config.private)
    
    # or generate one
    else
      Xmpp.private_key = new DSA()
      config.private = Xmpp.private_key.packPrivate()
      @save()

    # extend Xmpp.conn.first_message
    _first_message = Xmpp.conn.first_message
    Xmpp.conn.first_message = (message,stanza) =>
      from = stanza.attrs.from
      handle = _first_message(message,stanza)
      if stanza.attrs.type is "chat" # add otr for chat type message
        options =
          fragment_size: 140
          send_interval: 200
          debug:         on,
          priv: Xmpp.private_key
        stanza = {attrs:{from:from,type:"chat",type:"chat"}}
        handle.reply = (data) => handle.otr.sendMsg(data)
        handle.otr = otr = new OTR(options)
        otr.end = => otr.endOtr()
        otr.on "ui", (msg) => Xmpp.handle_message(msg, stanza, handle)
        otr.on "io", (msg) => Xmpp.send_to(from, msg)
        otr.on "status", (msg) => console.log "STATUS #{msg}"
        otr.on "error", (err) => console.log "OTR ERROR: #{err}"
        otr.on "smp", (type, data) =>
          console.log "SMP",type, data
          switch type
            when "trust"
              if data is on
                console.log "LOGIN!!!"
            when "question"
              otr.smpSecret "ghandi"
            else console.log "Unknown type."
      return handle

    # replace Xmpp.conn.message
    Xmpp.conn.message = (message,stanza) =>
      handle = Xmpp.conn.cache[stanza.attrs.from]
      handle = Xmpp.conn.first_message(message,stanza) unless handle?
      return handle.otr.receiveMsg(message) if handle.otr?
      return Xmpp.handle_message(message, stanza, handle)

    @new_command
      cmd   : '!otr'
      admin : yes
      args  : yes
      fnc   : (request,args) =>
        [action,arg] = args
        switch action
          when "fingerprint"
            unless Xmpp.private_key?
              return request.reply "No key exists, use 'keygen' to create."
            request.reply Xmpp.private_key.fingerprint()
          when "keygen"
            if config.private? and arg is "force"
              return request.reply "Key exists, 'force' to override"
            myKey = new DSA()
            config.private = myKey.packPrivate()
            request.reply @config.xmpp.private
            @save()