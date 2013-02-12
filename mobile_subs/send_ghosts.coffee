for key, value of require('../lib/apnshit/common')
  eval("var #{key} = value;")

apnshit = require('../lib/apnshit')
fs      = require('fs')
_       = require('underscore')

Apnshit      = apnshit.Apnshit
Notification = apnshit.Notification
Feedback     = apnshit.Feedback

config = fs.readFileSync("test/config.json")
config = JSON.parse(config)

apns = new Apnshit(
  cert          : config.cert
  debug         : true
  debug_ignore  : [
    'connect#start'
    'connect#exists'
    'send#start'
    'keepSending'
    'send#write'
    'send#written'
  ]
  key    : config.cert
  gateway: "gateway.push.apple.com"
)

apns.on 'debug', console.log

feedback = new Feedback(
  address       : "feedback.push.apple.com"
  cert          : config.cert
  debug         : true
  debug_ignore  : [ 
    'connect#start'
  ]
  interval      : 15
  key           : config.cert
)

feedback.on 'debug', console.log
feedback.on 'feedback', (time, device_id) =>
  console.log('feedback', time, device_id)

devices = JSON.parse(fs.readFileSync('mobile_subs/devices/devices.json'))
devices = devices.devices

noti = new Notification()
noti.badge = 0

setTimeout(
  =>
    _.each devices, (device_id) ->
      n = noti
      n.device = device_id
      console.log("sending: ",n.toJSON()," to device_id: ",device_id)
      apns.enqueue(n)
  5000
)


