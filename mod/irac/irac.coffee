crypto = require 'crypto'; sha512 = (data) -> crypto.createHash('sha512').update(data).digest("hex")
dgram  = require 'dgram'
events = require 'events'
nc     = require 'ncurses'
fs     = require("fs")

identity = "#{process.env.HOME}/.ssh/id_rsa" if process.env.HOME
unless identity or process.env.IDENTITY_FILE
  console.error "IDENTITY_FILE ENV var required"
  process.exit 1
identity = process.env.IDENTITY_FILE unless identity?
signingKey = undefined
fs.readFile identity, "ascii", (err, file) ->
  if err
    console.error err
    process.exit 1
  signingKey = file
  console.log "Signing key is: #{signingKey.trim()}"
  alg = (if RegExp(" DSA ").test(signingKey) then "DSA-SHA1" else "RSA-SHA256")
  console.log "Algorithm is: #{alg}"
  signer = crypto.createSign(alg)
  now = new Date().toUTCString()
  signer.update now
  signature = signer.sign(signingKey, "base64")
  console.log "Signature is: ", signature
  process.exit 0

class Channel
  udp : null
  member : {}
  constructor : (opts={}) ->
    { @name, @udp } = opts
  join : (p) -> @member[p.id] = p unless @member[p.id]?
  part : (p) -> delete @member[p.id] if @member[p.id]?
  cast : (m) ->
    m = new Buffer(JSON.stringify(m))
    @udp.send m, 0, m.length, node.port, node.address for key, node of @member

class IRAC extends events.EventEmitter
  peer : {}
  channel : {}
  constructor : (@name,opt={}) ->
    super
    { @udp_port, ready } = opt
    @udp_port = 4321 unless @udp_port
    @on "ready", ready if typeof ready is "function"
    @hash = sha512(@name)
    @udp = dgram.createSocket 'udp4'
    @udp.on 'error', (e) => console.log "(#{@name}::udp) error", e
    @udp.on 'close', (e) => console.log "(#{@name}::udp) close", e
    @udp.on 'listening', () =>
      console.log "(#{@name}::udp) listening @#{@udp_port}"
      @emit "ready"
    @udp.on 'message', @parse_message
    @on 'connect', @on_connect
    # @on 'message', @on_message # stub
    @on 'join', @on_join
    @on 'part', @on_part
    @udp.bind @udp_port
  parse_message : (d,p) =>
    p = @discover_peer(p)
    try m = JSON.parse(d)
    catch e
     return console.log "(#{@name}::udp) faulty message: #{e}"
    m.peer = p
    # console.log m
    switch m.type
      when "join", "part", "create", "message", "connect" then @emit m.type, m
      else console.log "(#{@name}::udp) illegal message: #{m.type}"
  send : (m,address,port) ->
    @discover_peer { address : address, port : port }
    @udp.send(m = new Buffer(JSON.stringify(m)), 0, m.length, port, address)
  _send : (m,address,port) ->
    @udp.send(m = new Buffer(JSON.stringify(m)), 0, m.length, port, address)
  cast : (msg) ->
    m = new Buffer(JSON.stringify(msg))
    @udp.send m, 0, m.length, node.port, node.address for key, node of @peer
  discover_channel : (c) ->
    return @channel[c.name] if @channel[c.name]?
    c.udp = @udp
    return @channel[c.name] = new Channel(c)
  discover_peer : (p) ->
    pid = "#{p.address}/#{p.port}"
    return @peer[pid] if @peer[pid]?
    # console.log "discover", p
    return @peer[pid] = { address : p.address, port : p.port, id : pid }
  connect : (p={}) -> @send { type: "connect", user : @name, port : @udp_port }, p.address, p.port
  join : (o={})    -> @cast { type: "join", channel:o}
  message : (c,m)  -> @cast { type: "message", channel:c, message:m }
  vote_op : (c,m)  ->
    # m = @sign(@describe_peer(m)) # TODO.1
    @cast { type: "vote:op", channel:c, message:m }
  on_connect : (m) ->
    # console.log "(#{@name}::udp) on_connect", m
    m.peer.user = m.user
  on_message : (m) -> console.log m
  on_join : (m) ->
    console.log "(#{@name}::udp) on_join", m
    c = @discover_channel(m.channel)
    c.join m.peer
  on_part : (m) ->
    console.log "(#{@name}::udp) on_part (#{m.nick})", m
    c = @discover_channel(m)
    c.part m.peer

module.exports = IRAC