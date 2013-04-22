###
  Abstract ncurses CLI
  TODO: ADD multiwindow (scope: refactor + trivial)
        FIX key mess (scope: unclear)
###

nc = require 'ncurses'
util = require 'util'

COLOR_ERROR = 4
COLOR_LOG = 6
COLOR_INFO = 5
COLOR_WARN = 4
COLOR_USER = 6
COLOR_SCOPE = 7
COLOR_CHAT = 5
COLOR_MENTION = 4
COLOR_JOIN = 6
COLOR_PART = 7
COLOR_EXEC = 3

EditableBuffer = (opts={}) ->
  { 
    initial, width, height, top, left,
    on_exec, on_complete, on_scroll, prompt
  } = opts
  win   = new nc.Window height, width
  _this = win
  ### MIND THE GAP!
    callbacks (=>) are bound to win not to ChatWindow
  ###
  win.EditableBuffer = =>
    @nc = nc # reference to ncurses
    @history = []
    @historyPos = -1
    @historyEnd = true
    @move top, left
    @buffer = initial.split("\n")
    @on "inputChar", @input_char
    @scrollok(true)
    @idlok(true)
    @idcok(true)
    @top()
    @prompt()
  win.toString = =>
    return @buffer.join("\n")
  win.bufferLoad = (b) ->
    @buffer = b.split("\n")
    @erase()
    @prompt()
    @print b
    @cursor 0, @promptlen
    @refresh()
  win.historyExec = (c) ->
    @history.push c if c isnt @history[@history.length-1]
    @historyEnd = true
    @historyPos = @history.length - 1
    @bufferLoad ""
  win.historyUp = =>
    return unless @history.length > 0
    if @historyEnd
      @historyEnd = false
      c = @toString()
      if c.length > 0 and @history[@history.length-1] isnt c
        @history.push c
        @historyPos = @history.length - 2
      else @historyPos = @history.length - 1
      @bufferLoad @history[@historyPos]
      return
    else
      return if @historyPos is 0
      @bufferLoad @history[--@historyPos]
  win.historyDown = =>
    unless @historyEnd
      @historyPos++
      @historyEnd = (@historyPos is (@history.length - 1))
      @bufferLoad @history[@historyPos]
  win.input_char = (char,code,isKey) =>
    console.log char, code, isKey if @debugKeys
    _this = win # this is cruel i know :D
    prev_y = @cury
    prev_x = @curx
    plus = 0
    plus = @promptlen if prev_y is 0
    if @escseq is on
      return if code is 91
      switch code
        when 54 then return on_scroll 1
        when 53 then return on_scroll -1
        when 10
          @buffer.insert prev_y+1, ""
          @print "\n"
          @cursor prev_y+1, 0
        when 65 then @historyUp()
        when 66 then @historyDown()
        when 68
          unless prev_y is 0 and prev_x < @promptlen + 1
            if prev_x is 0 and prev_y > 0
              prev_y--; prev_x = @width
            @cursor prev_y, prev_x - 1
        when 67
          if prev_x < @buffer[prev_y].length + plus
            @cursor prev_y, prev_x + 1
        else console.warn "unbound_keydown:: '#{char}', 0d#{code}"
      @escseq = false
      return @refresh()
    switch code
      when nc.keys.BACKSPACE, 127
        if prev_x > plus
          prev_x = prev_x - 1
          @delch prev_y, prev_x
          @buffer[prev_y] = @buffer[prev_y].substring(0, prev_x - plus) + @buffer[prev_y].substring(prev_x - plus + 1)
          @cursor prev_y, prev_x
      when nc.keys.DEL
        @delch prev_y, prev_x
        n = @buffer[prev_y]
        r = n.substring(prev_x)
        @buffer[prev_y] = n.substring(0, prev_x - 1) + r
        @cursor prev_y, prev_x
      when nc.keys.END, 338
        @cursor prev_y, @buffer[prev_y].length + plus
      when nc.keys.TAB, 9
        r = @on_complete @toString()
        return unless r isnt false
        if typeof r is "string"
          @bufferLoad r
        else console.info r
      when nc.keys.HOME, 339
        @cursor prev_y, 0 + plus
      when 27
        @escseq = on
      when nc.keys.NEWLINE
        c = @toString()
        on_exec c
        @historyExec c
      else
        if code >= 32 and code <= 126
          r = char + @buffer[prev_y].substring(prev_x-plus)
          @buffer[prev_y] = @buffer[prev_y].substring(0,prev_x-plus) + r
          @print r
          @cursor prev_y, prev_x + 1
        else
          console.warn "unbound_keydown:: '#{char}', 0d#{code}"
    @refresh()
  if prompt? then win.prompt = prompt
  else win.prompt = =>
    @print "["
    @attron nc.colorPair COLOR_USER
    @print process.env.USER
    @attroff nc.colorPair COLOR_USER
    @print "] "
    @promptlen = @curx
  win.EditableBuffer()
  return win

ChatWindow = (opts={}) ->
  win = new nc.Window()
  win.scrollok(true)
  win.hline nc.cols, nc.ACS.HLINE
  _this = win
  ### MIND THE GAP!
    callbacks (=>) are bound to win not to ChatWindow
  ###
  win.chat = (nick, message, nickcolor = 6, msgcolor = 7) =>
    prev_y = @out.cury
    @print "["
    @attron nc.colorPair nickcolor
    @print nick
    @attroff nc.colorPair nickcolor
    @print "] "
    @attron nc.colorPair msgcolor
    @print message
    @attroff nc.colorPair msgcolor
    @print "\n"
    @refresh()
  win.log = (type,color,args) =>
    @print "["
    @attron nc.colorPair color
    @print type
    @attroff nc.colorPair color
    @print "]"
    if typeof args is "string"
      @print " "+args
    else for k,v of args
      @print(" "+v) if (t = typeof v) is "string" or t is "number" or t is "boolean"
      @print(" "+util.inspect(v)) if typeof v is "object"
    @print "\n"
    @refresh()
  return win

class CLI
  nc : nc
  constructor : (opts={}) ->
    { input, output } = opts
    console.log "create win.output"
    @out = ChatWindow output
    console.warn  = => @out.log("warn" ,COLOR_WARN,arguments)
    console.info  = => @out.log("info" ,COLOR_INFO,arguments)
    console.error = => @out.log("error",COLOR_ERROR,arguments)
    console.log   = => @out.log("log"  ,COLOR_LOG,arguments)
    console.log "create win.input"
    input.height  = 1             unless input.height?
    input.width   = nc.cols       unless input.width?
    input.top     = nc.lines-1    unless input.top?
    input.left    = 0             unless input.left?
    input.initial = ""            unless input.initial?
    input.on_scroll = @out.scroll unless input.on_scroll?
    @in  = EditableBuffer input

module.exports = CLI