
module.exports = () ->
  
  Promise = require('bluebird')
  fs = require('fs')
  restAPI = require('./restAPI')
  http = Promise.promisifyAll(require('http'))
  Mplayer = require('mplayer')
  Cron = require('node-schedule')
  
  class Application
    
    constructor: () ->
      @_appConfig = process.cwd() + '/config.json'
      @settings = require(@_appConfig)
      @_today = null
      @_jobs = {}
      @weekdays = [
        "sunday",
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday"
      ]
      
      @_player = new Mplayer()
      @_rest = new restAPI()
      @_rest.init(3000, @)
      @_rest.on('stopAlarm', @stopAlarm)
      @_rest.on('activateAlarm', @activateAlarm)
      @_rest.on('configUpdated', @updateConfig)
      
      @_rest.startServer()
    
    activateAlarm: (data) =>
      # Activate the Alarm
      @_playAudio(data.resource)
      
      # Trigger Home automation
      settings = require('../config.json')
      endPoint = 'http://' + settings.config.smartHome.user + ':' + settings.config.smartHome.passwd + '@' + settings.config.smartHome.host + settings.config.smartHome.endPoint
      http.get(endPoint , (res) =>
        contentType = res.headers['content-type']
        
        if res.statusCode != 200
          error = new Error('Request failed.\nStatus code: ' + res.statusCode)
          
        else if !/^application\/json/.test(contentType)
          error = new Error('Invalid content type\nExpected application/json but got ' + contentType)
        
        if error?
          console.log(error.message)
          res.resume()
          return
        
        res.setEncoding('utf8')
        rawData = ''
        res.on('data', (chunk) =>
          rawData += chunk
        )
        res.on('end', () =>
          data = JSON.parse(rawData)
          if data.success
            console.log("Home automation triggered.\n")
        )
        res.on('error', (err) =>
          console.error(err.message)
        )
      )
      
      console.log('Alarm clock activated.')
    
    stopAlarm: () =>
      @_player.stop()
      clearTimeout(@_volIncrease)
    
    updateConfig: (settings) =>
      console.log('Reloading config...')
      @_saveConfig(settings)
      @settings = require(@_appConfig)
      @updateCron(@settings.schedule.days)
      
    updateCron: (days) =>
      days.map( (day) =>
        @_jobs[day.id].cancel() if @_jobs[day.id]?
        delete @_jobs[day.id]
        
        if day.enabled
          time = day.time.split(':')
          dayOfWeek = null
          @weekdays.map( (weekday, index) =>
            dayOfWeek = index if weekday is day.id
          )
          
          rule = new Cron.RecurrenceRule()
          rule.dayOfWeek = dayOfWeek
          rule.hour = time[0]
          rule.minute = time[1]
          
          j = Cron.scheduleJob(rule, () =>
            console.log(Date().toString())
            @activateAlarm(day)
          )
          @_jobs[day.id] = j
      )
      console.log(Date().toString())
      console.log('Updated Alarm Schedule:')
      console.log(obj.nextInvocation().toString()) for job, obj of @_jobs
    
    _playAudio: (resource) =>
      @_volume = {
        min: 0,
        max: 35,
        next: 0
      }
      time = 60 * 1000
      @_interval = 2 * 1000
      @_increment = Math.round( (@_volume.max - @_volume.min) / (time / @_interval) )
      
      @_player.openFile(resource)
      @_player.volume(@_volume.min)
      @_player.play()
      
      @_volIncrease = setTimeout(@_autoIncreaseVolume, @_interval, @_volume.next)
      
    _autoIncreaseVolume: (volume) =>
      @_player.volume(volume)
      @_volume.next += @_increment
      
      if @_volume.next <= @_volume.max
        @_volIncrease = setTimeout(@_autoIncreaseVolume, @_interval, @_volume.next)
    
    _saveConfig: (settings, file) =>
      settings ?= @settings
      file ?= @_appConfig
      
      fs.writeFile(file, JSON.stringify(settings, null, 2), (err) =>
        if err?
          return console.log('Error writing config file:' + err)
        )
    
    destroy: () ->
      @_player.removeAllListeners('status')
      @_rest.removeListener('stopAlarm', @stopAlarm)
      @_rest.removeListener('activateAlarm', @activateAlarm)
      @_rest.removeListener('configUpdated', @updateConfig)
  
  return new Application