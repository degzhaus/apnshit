for key, value of require('./apnshit/common')
  eval("var #{key} = value;")

Feedback     = require './apnshit/feedback'
Notification = require './apnshit/notification'

class Apnshit extends EventEmitter
  
  constructor: (options) ->
    @current_id    = 0
    @notifications = []
    @sent          = []
    
    @options =
      ca                   : null
      cert                 : 'cert.pem'
      debug                : false
      debug_ignore         : []
      enhanced             : true
      gateway              : 'gateway.push.apple.com'
      infinite_resend_limit: 10
      key                  : 'key.pem'
      passphrase           : null
      port                 : 2195
      reject_unauthorized  : true
      timeout              : 3000

    _.extend(@options, options)

    # EventEmitter requires something bound to error event
    @on('error', ->)

    @attachDebugEvents() if @options.debug
    @keepSending()

  attachDebugEvents: ->
    _.each @events, (e) =>
      @on e, (a, b) =>
        return if @options.debug_ignore.indexOf(e) >= 0
        if e == 'send#write'
          @emit('debug', e, a.alert)
        else if e == 'socketData#invalid_token#notification'
          @emit('debug', e, a.alert)
        else if e == "disconnect#drop#resend"
          @emit('debug', e, a.length)
        else if e == "socketData#start"
          @emit('debug', e, a[0])
        else if e == "socket#error"
          @emit('debug', e, a)
        else if e == "socketData#found_notification"
          @emit('debug', e, a)
        else if e == "send#start"
          @emit('debug', e, a)
        else
          @emit('debug', e)

  checkForStaleConnection: ->
    @emit('checkForStaleConnection#start')

    if @socket
      stale = (
        @socket.socket.bytesRead    == @bytes_read &&
        @socket.socket.bytesWritten == @bytes_written
      )

      @stale_count ||= 0
      @stale_count++

      if @stale_count >= 2
        clearInterval(@stale_connection_timer)
        
        delete @stale_connection_timer
        delete @stale_count
        
        @emit('checkForStaleConnection#stale')
        @emit('finish')

      @bytes_read    = @socket.socket.bytesRead
      @bytes_written = @socket.socket.bytesWritten

  connect: ->
    @emit('connect#start')

    unless @socket && @socket.writable
      delete @connect_promise

    @connect_promise ||= defer (resolve, reject) =>
      if @socket && @socket.writable
        @emit('connect#exists')
        resolve()
      else
        @emit('connect#connecting')

        delete @bytes_read
        delete @bytes_written
        delete @stale_count
        
        socket_options =
          ca                : @options.ca
          cert              : fs.readFileSync(@options.cert)
          key               : fs.readFileSync(@options.key)
          passphrase        : @options.passphrase
          rejectUnauthorized: @options.reject_unauthorized
          socket            : new net.Stream()
    
        setTimeout(
          =>
            @socket = tls.connect @options.port, @options.gateway, socket_options, =>
              @emit("connect#connected")
              resolve()

            @socket.on "close",        => @socketError()
            @socket.on "data" , (data) => @socketData(data)
            @socket.on "error", (e)    => @socketError(e)

            @socket.setNoDelay(false)
            @socket.socket.connect(@options.port, @options.gateway)
          100
        )

  enqueue: (notification) ->
    @emit("enqueue", notification)

    @current_id = 0  if @current_id > 0xffffffff
    notification._uid = @current_id++
    
    @notifications.push(notification)

    @stale_connection_timer ||= setInterval(
      => @checkForStaleConnection(),
      Math.floor(@options.timeout / 2)
    )

  events: [
    "checkForStaleConnection#start"
    "checkForStaleConnection#stale"
    "connect#start"
    "connect#exists"
    "connect#connecting"
    "connect#connected"
    "enqueue"
    "keepSending"
    "send#start"
    "send#write"
    "send#written"
    "socketData#start"
    "socketData#found_notification"
    "socketError#start"
  ]

  keepSending: ->
    process.nextTick(
      =>
        @emit("keepSending")
        @send() if !@sending && @notifications.length
        @keepSending()
    )

  send: ->
    notification = @notifications.shift()

    if notification
      @sending = true
      @emit("send#start", JSON.stringify(notification), notification.device)

      data           = undefined
      encoding       = notification.encoding || "utf8"
      message        = JSON.stringify(notification)
      message_length = Buffer.byteLength(message, encoding)
      position       = 0
      token          = new Buffer(notification.device.replace(/\s/g, ""), "hex")

      if @options.enhanced
        data = new Buffer(1 + 4 + 4 + 2 + token.length + 2 + message_length)
        data[position] = 1
        position++
        data.writeUInt32BE notification._uid, position
        position += 4
        data.writeUInt32BE notification.expiry, position
        position += 4
      else
        data = new Buffer(1 + 2 + token.length + 2 + message_length)
        data[position] = 0
        position++
      
      data.writeUInt16BE token.length, position
      position += 2
      position += token.copy(data, position, 0)
      
      data.writeUInt16BE message_length, position
      position += 2
      position += data.write(message, position, encoding)
      
      @connect().then(
        =>
          @emit("send#write", notification)
          @sent.push(notification)
          
          if @socket.writable
            @socket.write data, encoding, =>
              @emit("send#written", notification)
              @sending = false
              notification._written = true
          else
            @notifications.unshift(notification)
            @sent = _.reject(@sent, (n) => n._uid == notification._uid)
            @sending = false
      )

  socketData: (data) ->
    @emit('socketData#start', data)

    error_code = data[0]
    identifier = data.readUInt32BE(2)

    notification = _.find @sent, (item, i) =>
      item._uid == identifier
    
    if notification
      @emit('socketData#found_notification', notification)
      @emit('error', notification)  if error_code == 8

      @notifications = @notifications.concat(
        @sent.slice(
          @sent.indexOf(notification) + 1
        )
      )

      console.log('@notifications', @notifications.length)

      _.each(@notifications, (n) => delete n._written)

      @sent = []
      @socket.writable = false

  socketError: (e) ->
    @emit('socketError#start', e)

    @notifications = @notifications.concat(
      _.reject(@sent, (n) => n._written)
    )
    @socket.writable = false

module.exports = 
  Apnshit     : Apnshit
  Feedback    : Feedback
  Notification: Notification