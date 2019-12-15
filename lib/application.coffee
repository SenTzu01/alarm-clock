  Promise = require('bluebird')
  fs = require('fs')
  restAPI = require('./restAPI')
  Alarm = require('./Alarm')
  http = require('http')
  #Mplayer = require('mplayer')
  Cron = require('node-schedule')
  Express = require('express')
  
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
      
      @_alarm = new Alarm()
      
      @updateCron(@settings.schedule)
      
      @_httpServer = new Express()
      @_httpServer.use(Express.static(@settings.config.httpServer.static_dir))
      
      @_rest = new restAPI(@_httpServer, @settings.rest)
      .smartHome(@settings.config.smartHome)
      .playback(@settings.config.playback)
      .schedule(@settings.schedule, @updateSchedule)
      .config(@settings.config, @updateConfig)
      .on('stopAlarm', @stopAlarm)
      .on('activateAlarm', @activateAlarm)
      .on('setVolume', @setVolume)
      .startServer(@settings.config.httpServer.port)
      
    activateAlarm: (data) =>
      @_alarm.range(@settings.config.playback.volume.min, @settings.config.playback.volume.max)
      .timer(@settings.config.playback.volume.increaseTimer)
      .localAudio(@settings.config.playback.fallback)
      .start(data.resource)
      
      @triggerSmartHome() if data.triggerSmartHome # @settings.config.smartHome
      
      console.log('Alarm activated.')
    
    stopAlarm: () =>
      @_alarm.stop()
    
    triggerSmartHome: (server) =>
      server = server || @settings.config.smartHome
      endPoint = 'http://' + server.user + ':' + server.passwd + '@' + server.host + server.trigger.endPoint
      http.get(endPoint , (res) =>
        contentType = res.headers['content-type']
        
        if res.statusCode != 200
          error = new Error('Request failed.\nStatus code: ' + res.statusCode)
          
        else if !/^application\/json/.test(contentType)
          error = new Error('Invalid content type\nExpected application/json but got ' + contentType)
        
        if error?
          console.error(error.message)
          res.resume()
          return
        
        res.setEncoding('utf8')
        rawData = ''
        res.on('data', (chunk) =>
          rawData += chunk
        )
        res.on('end', () =>
          data = JSON.parse(rawData)
          console.log('Smart home activation result: ' + data.success)
        )
        res.on('error', (err) =>
          console.error(err.message)
        )
      )
    
    getPresence: (server) =>
      return new Promise( (resolve, reject) =>
        endPoint = 'http://' + server.user + ':' + server.passwd + '@' + server.host + server.presence.endPoint
        http.get(endPoint , (res) =>
          contentType = res.headers['content-type']
          
          if res.statusCode != 200
            error = new Error('Request failed.\nStatus code: ' + res.statusCode)
            
          else if !/^application\/json/.test(contentType)
            error = new Error('Invalid content type\nExpected application/json but got ' + contentType)
          
          if error?
            console.error(error.message)
            res.resume()
            reject(error.message)
          
          res.setEncoding('utf8')
          rawData = ''
          res.on('data', (chunk) =>
            rawData += chunk
          )
          res.on('end', () =>
            data = JSON.parse(rawData)
            resolve(data.variable.value)
          
          )
          res.on('error', (err) =>
            console.error(err.message)
            reject(err)
          )
        )
      )
    
    updateSchedule: (config) =>
      @settings.schedule = config if config?
      @updateSettings(@settings)
    
    updateConfig: (config) =>
      @settings.config = config if config?
      @updateSettings(@settings)
    
    updateSettings: (settings) =>
      console.log('Reloading config...')
      @settings = settings
      @_saveConfig(@settings)
      @updateCron(@settings.schedule)
    
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
            @activateAlarm(day)
          )
          @_jobs[day.id] = j
      )
      console.log('Updated Alarm Schedule:')
      console.log(obj.nextInvocation().toString()) for job, obj of @_jobs
    
    setVolume: (volume) =>
      @_alarm.volume(volume)
    
    _saveConfig: (settings, file) =>
      settings ?= @settings
      file ?= @_appConfig
      
      fs.writeFile(file, JSON.stringify(settings, null, 2), (err) =>
        if err?
          return console.error('Error writing config file:' + err)
        else
          console.log('Settings saved to: ' + file)
      )
    destroy: () ->
      return new Promise( (resolve, reject) =>
        @_rest.removeAllListeners('stopAlarm')
        @_rest.removeAllListeners('activateAlarm')
        @_rest.removeAllListeners('configUpdated')
        resolve()
      )
  
  module.exports = Application