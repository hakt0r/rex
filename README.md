## Rex - the automagic bot

Rex is an irc / xmpp / you-name-it bot-framework originally developed as helper
for the guerilla radio team. It's pretty young in it's node.js incarnation so
expect fluent api-changes and non-functional code at HEAD :D

For a full blown example of an app using Rex as an application-framework you
should have a look at [rtv](https://github.com/hakt0r/rtv).

### Installation

    $ sudo npm install -g git://github.com/hakt0r/rex.git

### CLI usage

    $ rex -i

  * -i : start in interactive ncurses mode (very experimental)

### Node.JS Usage:

Shamelessly ripped from the heart of rtv.

    Bot = require('./rex/lib/main.js')
    dirname = require('path').dirname
    dir = dirname(dirname(process.mainModule.filename))
    
    RTV = new Bot({
      "project" : dir,
      "project_lib" : dir + "/lib",
      "modules" : [ "rtv" ]
    })

    module.exports = RTV

### Copyrights and License

  * (c) 2013 Sebastian Glaser <anx@ulzq.de>
  * Licensed under GNU GPLv3
