# Description:
#   Remind Google Calendar Events
#

module.exports = (robot) ->
  cronJob = require('cron').CronJob
  requestWithJWT = require('google-oauth-jwt').requestWithJWT()
  moment         = require('moment-timezone')
  _              = require('underscore')
  room = 'general'
  cronRanges = '0 25,55 * * * *'

  cronReminder = new cronJob(cronRanges, () ->
    try
      calendarEventsReminder new Date(), (str) ->
        if str.length > 0
          robot.messageRoom room, str
    catch e
      msg.send "exception: #{e}"
  )

  cronReminder.start()

  request = (opt, onSuccess, onError) ->
    params =
      jwt:
        email: process.env.HUBOT_GOOGLE_CALENDAR_EMAIL
        keyFile: process.env.HUBOT_GOOGLE_CALENDAR_KEYFILE
        scopes: ['https://www.googleapis.com/auth/calendar.readonly']

    _.extend(params, opt)

    requestWithJWT(params, (err, res, body) ->
      if err
        onError(err)
      else
        if res.statusCode != 200
          onError "status code is #{res.statusCode}"
          return

        onSuccess JSON.parse(body)
    )

  formatEvent = (event) ->
    strs = []
    if event.start
      if event.start.date
        strs.push event.start.date
      else if event.start.dateTime
        date = new Date(event.start.dateTime)
        strs.push "#{date.getHours()}:#{("0" + date.getMinutes()).slice(-2)}"

    if event.end
      strs.push "-"
      if event.end.date
        strs.push event.end.date
      else if event.end.dateTime
        date = new Date(event.end.dateTime)
        strs.push "#{date.getHours()}:#{("0" + date.getMinutes()).slice(-2)}"

    strs.push event.summary
    strs.join " "

  calendarEventsReminder = (baseDate, cb) ->
    onError = (err) ->
      cb "receive err: #{err}"

    request(
      { url: 'https://www.googleapis.com/calendar/v3/users/me/calendarList' }
      (data) ->
        timeMin = new Date(baseDate.getTime())
        timeMax = new Date(baseDate.getTime())
        timeMax.setMinutes(timeMax.getMinutes() + 10)
        for i, item of data.items
          do (item) ->
            request(
              {
                url: "https://www.googleapis.com/calendar/v3/calendars/#{item.id}/events"
                qs:
                  timeMin: moment(timeMin).tz(item.timeZone).format()
                  timeMax: moment(timeMax).tz(item.timeZone).format()
                  orderBy: 'startTime'
                  singleEvents: true
                  timeZone: item.timeZone
              }
              (data) ->
                strs = [':alarm_clock:\n']
                numItems = 0
                for i, item of data.items
                  if item.start.dateTime
                    startTime = new Date(item.start.dateTime)
                    if startTime < timeMin
                      continue
                  strs.push formatEvent(item)
                  numItems++
                if numItems == 0
                  cb ""
                else
                  cb strs.join("\n")
              onError
            )
      onError
    )
