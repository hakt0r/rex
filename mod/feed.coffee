###
  Newsfeed module - part of the rex project
  c) 2012 - 2013
    Sebastian Glaser <anx@ulzq.de>
  Licensed under GNU GPLv3
###

module.exports =
  defaults : { "http://blog.fefe.de/rss.xml" : { enabled : true } }
  deps : [ 'web', 'database' ]
  libs : [ 'feedparser' ]
  init : (config) ->
    { api, PREFIX } = this
    { request, iconv, feedparser, Web, feedparser } = api

    @api.Feed = Feed = @api.database.define "Feed",
      url:
        index : true
        type: String
        length: 255
      title:
        type: String
        length: 255
      source:
        type: String
        length: 255
      date:
        type: Date
        default: Date.now

    # link un-shortener (GET /l/id)
    Web.get "/[0-9]+", (req, res) =>
      visitor = req.connection.remoteAddress
      id = req.url.slice(1)
      Feed.findOne
        where:{id: id}
      , (error,result) =>
        #@debug {bot:{id:result.id,url:result.url}}
        if error then console.error error
        else if result then res.redirect result.url, 302
        else res.send "URL not found #{id}!", 404; res.end()

    @convert = { ISO885912UTF8 : new iconv.Iconv 'ISO-8859-1', 'UTF8' }

    cache = (article,callback) =>
      Feed.findOne
        where:{url: article.link}
      , (error,result) =>
        if result != null
          # console.log "cached: #{result.id}"
          return
        result = Feed.create
          url : article.link
          title : article.title
          source : article.meta.link
        , (err,result) =>
          # console.log "not cached: #{result.id}"
          callback(result)

    Feed.check = () =>
      for url, options of @config.feed
        # if typeof options = "boolean"
        #   options = {enabled:true}
        #   @config.feed[url] = options
        #   @save()
        { enabled } = options
        headers = {}
        headers["If-Modified-Since"] = options.lastmod if options.lastmod?
        headers["If-None-Match"] = options.etag if options.etag?
        if enabled
          request  {uri: url,headers: headers}, (err, response, body) =>
            return if err
            options.etag = headers.etag if headers.etag?
            options.lastmod = headers['last-modified'] if headers['last-modified']?
            body = @convert.ISO885912UTF8(body) if options.encoding? and options.encoding == "ISO-8859-1"
            p = feedparser.parseString(body)
              . on 'article', (article) =>
                return if ! article.title?
                cache article, (article) =>
                  @message
                    news :
                      title : article.title
                      id : article.id
                      link : article.url
                      source : article.source
              . on "error",(e) =>
                @message
                  debug : "Feed error: #{e}\n#{url}"

    setTimeout (=> Feed.check setInterval Feed.check, 60*10*1000), 10000

    @new_command
      cmd   : "!feed"
      admin : true
      args  : true
      fncs  :
        check : Feed.check
        help : (request, args) =>
          request.reply "Feed commands: list, check, sub, desub, " + 
            "blurb (on|off), add <feed>, del <feed>, url <#id>"
        list : (request, args) =>
          request.reply "List feeds:\n" +
            Object.keys(@config.feed).join("\n")
        url : (request, args) =>
          Feed.findOne {"where":{"id":args[1]}}, (e,r) =>
            return request.reply r[args[0]] if r? and r[args[0]]?
            request.reply "Not found #{args[1]}"
        replay : (request, args) =>
          Feed.findOne {where:{id:args[1]}}, (e,r) =>
            if r?
              return @message
                news :
                  title : r.title
                  id : r.id
                  link : r.url
                  source : r.source
            request.reply "Not found #{args[1]}"
        blurb : (request, args) =>
          if args[1] == "on" then @config.xmpp.blurb = true
          else @config.xmpp.blurb = false
          request.reply "Feedblurb: #{@config.xmpp.blurb}"
        add : (request, args) =>
          request.reply "Added feed: #{args[1]}"
          @config.feed[args[1]] = true
          Feed.check()
          @save()
        del : (request, args) =>
          request.reply "Deleted feed: #{args[1]}"
          delete @config.feed[args[1]]
          @save()