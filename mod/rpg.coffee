###
  Roleplay module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports = ->
  @new_command
    cmd  : "!d"
    args : yes
    fnc  : (request, args) =>
      for v in args
        if v.match /[0-9]+d[0-9]+(\+[0-9]+)?(\-[0-9]+)?/
          pass = undefined
          [c,v] = v.split 'd' if v.indexOf('d') isnt -1
          if v.indexOf('+') isnt -1
            [d,v] = v.split '+'; pass = on; d = parseInt d; p = parseInt v
          else if v.indexOf('-') isnt -1
            [d,v] = v.split '-'; pass = off; d = parseInt d; p = parseInt v
          else d = parseInt v
          c = parseInt c; v = []
          for i in [0...c]
            r = Math.floor 1 + Math.random() * d
            if pass?
              v.push if pass
                  if r >= p then "pass[#{r}]" else "fail[#{r}]"
                else
                  if r <= p then "pass[#{r}]" else "fail[#{r}]"
            else v.push r
          args[k] = v.join(' ')
      return request.public_reply args.join(', ') if request.type is "groupchat"
      return request.reply args.join(', ')