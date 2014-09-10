# Description:
#   Give and List User Marks
#
# Dependencies:
#   bitmarkd must be running
#   bitmark-cli must be in path
#   wallet must be funded
#
# Configuration:
#   None
#
# Commands:
#   mark     <user> <amount>          - mark user amount
#   withdraw <address> <amount>       - withdraw to address amount
#   balance  <user>                   - balance for a user
#
# Author:
#   bitmark team
#


# requires
exec = require('child_process').exec;


# init
credits  = {} # simple key value store or URI / balance for now
symbol   = '₥'
secret   = process.env.HUBOT_DEPOSIT_SECRET
if process.env.HUBOT_ADAPTER is 'irc'
  adapter = 'irc'
  irc_server = process.env.HUBOT_IRC_SERVER
else if process.env.HUBOT_ADAPTER is 'slack'
  adapter = 'slack'
  slack_team = process.env.HUBOT_SLACK_TEAM
else
  throw new Error('HUBOT_ADAPTER env variable is required')


# functions
to_URI = ( id ) ->
  if adapter is 'irc'
    'irc://' + id + '@' + irc_server + '/'
  else if adapter is 'slack'
    'https://' + slack_team + '.slack.com/team/' + id + '#this'

from_URI = ( URI ) ->
  if adapter is 'irc'
    URI.split(":")[1].substring(2).split('@')[0]
  else if adapter is 'slack'
    URI.split(":")[1].substring(2).split('/')[2].split('#')[0]


#   deposit  <user> <amount> <secret> - deposit amount using shared secret
deposit_credits = (msg, URI, amount) ->
  credits[URI] ?= 0
  credits[URI] += parseFloat(amount)
  msg.send amount + symbol + ' to ' + from_URI(URI)

transfer_credits = (msg, URI, amount) ->
  if credits[to_URI(msg.message.user.name)] >= parseFloat(amount)
    credits[URI] ?= 0
    credits[URI] += parseFloat(amount)
    credits[to_URI(msg.message.user.name)] -= parseFloat(amount)
    msg.send amount + symbol + ' has been awarded to ' + from_URI(URI)
  else
    msg.send 'not enough funds'

withdraw_credits = (msg, address, amount) ->
  if credits[to_URI(msg.message.user.name)] >= parseFloat(amount)
    command = 'bitmark-cli sendtoaddress ' + address + ' ' + ( parseFloat(amount) / 1000.0 )
    console.log(command)
    exec command, (error, stdout, stderr) ->
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      credits[to_URI(msg.message.user.name)] -= parseFloat(amount)
      msg.send stdout
  else
    msg.send 'not enough funds'


save = (robot) ->
  robot.brain.data.credits = credits


# MAIN
module.exports = (robot) ->
  robot.brain.on 'loaded', ->
    credits = robot.brain.data.credits or {}

  # DEPOSIT
  robot.hear /deposit @?([^ ]*) (\d+) ([^ ]*)$/i, (msg) ->
    if msg.match[3] is secret
      msg.send 'deposit to ' + msg.match[1] + ' ' + msg.match[2]
      deposit_credits(msg, to_URI(msg.match[1]), msg.match[2])
      save(robot)
        
  # TRANSFER
  robot.hear /(transfer|mark) @?([\w\S]+) (\d+)$/i, (msg) ->
    transfer_credits(msg, to_URI(msg.match[2]), msg.match[3])
    save(robot)

  # WITHDRAW
  robot.hear /withdraw ([\w\S]+) (\d+)$/i, (msg) ->
    withdraw_credits(msg, msg.match[1], msg.match[2])
    save(robot)
    
  # BALANCE
  robot.hear /balance @?([\w\S]+)$/i, (msg) ->
    URI = to_URI(msg.match[1])
    credits[URI] ?= 0
    msg.send from_URI(URI) + ' has ' + credits[URI] + symbol
  
       
