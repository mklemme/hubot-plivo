# Description:
#   An adapter for Plivo (sms service)
#
# Dependencies:
#   "hubot": "2"
#
# Configuration:
#   HUBOT_PLIVO_AUTH_ID     | Your Plivo auth id
#   HUBOT_PLIVO_AUTH_TOKEN  | Your Plivo auth token
#   HUBOT_PLIVO_FROM        | Your purchased Plivo phone number
#   HUBOT_BASE_URL          | Your base hubot url including the trailing slash
#
# Commands:
#   hubot <trigger> - <what the respond trigger does>
#   <trigger> - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Myk Klemme (@mklemme)
#
try
  {Robot,Adapter,TextMessage,User} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,Adapter,TextMessage,User} = prequire 'hubot'

HTTP    = require "http"
QS      = require "querystring"

class Plivo extends Adapter
  constructor: (robot) ->
    @sid   = process.env.HUBOT_PLIVO_AUTH_ID
    @token = process.env.HUBOT_PLIVO_AUTH_TOKEN
    @from  = process.env.HUBOT_PLIVO_FROM
    @robot = robot
    super robot

  send: (envelope, strings...) ->
    user = envelope.user
    message = strings.join "\n"

    @send_sms message, user.id, (error, body) ->
      if error or not body?
        console.log "Error sending outbound SMS: #{error}"

  reply: (user, strings...) ->
    @send user, str for str in strings

  respond: (regex, callback) ->
    @hear regex, callback

  run: ->
    self = @

    @robot.router.post "/hubot/sms", (request, response) =>
      message = request.body.Text
      from = request.body.From
      to = request.body.To


      if from? and message?
        user = @robot.brain.userForId from
        @receive_sms(message, from, user)

        @robot.emit "sms:received", {
          from : from,
          to: to,
          message: message,
          user: user
        }

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

    @robot.router.post "/hubot/sms/webhook", (request, response) =>
      message = request.body.message
      error = request.body.error

      if message?
        console.log message
      if error?
        console.log error

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

    self.emit "connected"

  receive_sms: (body, from, user) ->
    return if body.length is 0

    @receive new TextMessage user, body, 'messageId'

  send_sms: (message, to, callback) ->

    sleep = (ms) ->
      start = new Date().getTime()
      continue while new Date().getTime() - start < ms

    if message.length > 1600
      message = message.substring(0, 1582) + "...(msg too long)"

    if message.length > 150
      messages = message.match(new RegExp('.{1,' + 150 + '}', 'g'));
    else
      messages = [message]

    user = @robot.brain.userForId to

    for sms in messages

      data = JSON.stringify({
          src: @from,
          dst: to,
          text: sms,
          url: process.env.HUBOT_BASE_URL + "/hubot/sms/webhook/"
        })

      authHeader = 'Basic ' + new Buffer(@sid + ':' + @token)
        .toString('base64')

      @robot.http("https://api.plivo.com")
        .path("/v1/Account/" + @sid + "/Message/")
        .header("Content-Type","application/json")
        .header("Authorization", authHeader)
        .header("User-Agent", "NodePlivo")
        .post(data) (err, res, body) ->
          if err
            callback err
          else if res.statusCode is 202
            json = JSON.parse(body)
            callback null, json
          else
            json = JSON.parse(body)
            callback json

      @robot.emit "sms:sent", {
        from: @from,
        to: to,
        message: sms,
        user: user
      }

      sleep 1000

exports.Plivo = Plivo

exports.use = (robot) ->
  new Plivo robot
