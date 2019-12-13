module.exports = () ->
  
  Promise = require('bluebird')
  fs = require('fs')
  restAPI = require('./restAPI')
  http = require('http')
  Mplayer = require('mplayer')
  Cron = require('node-schedule')
  express = require('express')
  
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
      
      @_httpServer = express()
      @_httpServer.use(express.static(@settings.config.httpServer.static_dir))
      
      @_player = new Mplayer()
      
      @updateCron(@settings.schedule.days)
      
      @_rest = new restAPI()
      @_rest.init(@_httpServer, @settings)
      
      @_rest.on('stopAlarm', @stopAlarm)
      @_rest.on('activateAlarm', @activateAlarm)
      @_rest.on('configUpdated', @updateConfig)
      @_rest.on('setVolume', @setVolume)
      
      @_rest.startServer(@settings.config.httpServer.port)
    
    activateAlarm: (data) =>
      @_playAudio(data.resource)
      if data.triggerSmartHome
        @triggerSmartHome(@settings.config.smartHome)
      console.log('Alarm activated.')
    
    stopAlarm: () =>
      @_player.stop()
      @_player.removeAllListeners('status')
      clearTimeout(@_volIncrease)
      console.log('Alarm stopped')
    
    triggerSmartHome: (server) =>
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
            @activateAlarm(day)
          )
          @_jobs[day.id] = j
      )
      console.log('Updated Alarm Schedule:')
      console.log(obj.nextInvocation().toString()) for job, obj of @_jobs
    
    setVolume: (volume) =>
      @_player.volume(volume)
    
    _playAudio: (resource) =>
      @_increment = Math.round( (@settings.config.volume.max - @settings.config.volume.min) / (@settings.config.volume.increaseTimer / @settings.config.volume.increaseInterval) )
      
      @setVolume(@settings.config.volume.min)
      @_volumeNext = @_increment
      
      @_player.openFile(resource)
      @_player.play()
      
      @_volIncrease = setTimeout(@_autoIncreaseVolume, @settings.config.volume.increaseInterval*1000, @_volumeNext)
      
    _autoIncreaseVolume: (volume) =>
      @setVolume(volume)
      @_volumeNext += @_increment
      
      if @_volumeNext <= @settings.config.volume.max
        @_volIncrease = setTimeout(@_autoIncreaseVolume, @settings.config.volume.increaseInterval*1000, @_volumeNext)
    
    _saveConfig: (settings, file) =>
      settings ?= @settings
      file ?= @_appConfig
      
      fs.writeFile(file, JSON.stringify(settings, null, 2), (err) =>
        if err?
          return console.error('Error writing config file:' + err)
        )
    
    destroy: () ->
      return new Promise( (resolve, reject) =>
        @_player.removeAllListeners('status')
        @_rest.removeAllListeners('stopAlarm')
        @_rest.removeAllListeners('activateAlarm')
        @_rest.removeAllListeners('configUpdated')
        resolve()
      )
  
  return new Application