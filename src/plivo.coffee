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
        @receive_sms(message, from)

        @robot.emit "sms:received", {
          from      : from,
          to        : to,
          message   : body,
          user      : user
        }

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()


    self.emit "connected"

  receive_sms: (body, from) ->
    return if body.length is 0
    user = @robot.brain.userForId from

    @receive new TextMessage user, body, 'messageId'

  send_sms: (message, to, callback) ->

    if message.length > 1600
      message = message.substring(0, 1582) + "...(msg too long)"

    data = JSON.stringify({
        src: @from,
        dst: to,
        text: message
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
        else if res.statusCode is 201
          json = JSON.parse(body)
          callback null, json
        else
          json = JSON.parse(body)
          callback json

    @robot.emit "sms:sent", {
      from: @from,
      to: to,
      message: message,
      user: user
    }

exports.Plivo = Plivo

exports.use = (robot) ->
  new Plivo robot
