

{Robot, Adapter, TextMessage}   = require("hubot")

HTTP    = require "http"
QS      = require "querystring"

class Plivo extends Adapter
  constructor: (robot) ->
    @sid   = process.env.HUBOT_SMS_SID
    @token = process.env.HUBOT_SMS_TOKEN
    @from  = process.env.HUBOT_SMS_FROM
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
      console.log response
      payload = QS.parse(request.url)
      console.log payload

      if payload.Body? and payload.From?
        @receive_sms(payload.Body.trim(), payload.From)

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

    auth = new Buffer(@sid + ':' + @token).toString("base64")
    data = QS.stringify From: @from, To: to, Body: message

    @robot.http("https://api.twilio.com")
      .path("/2010-04-01/Accounts/#{@sid}/Messages.json")
      .header("Authorization", "Basic #{auth}")
      .header("Content-Type", "application/x-www-form-urlencoded")
      .post(data) (err, res, body) ->
        if err
          callback err
        else if res.statusCode is 201
          json = JSON.parse(body)
          callback null, body
        else
          json = JSON.parse(body)
          callback body.message

exports.Plivo = Plivo

exports.use = (robot) ->
  new Twilio robot
