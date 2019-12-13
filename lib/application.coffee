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
      console.log('Volume set to: ' + volume)
    
    _playAudio: (resource) =>
      playing = false
      @_player.once('start', () => playing = true )
      @_player.stop()
      @_player.volume(@settings.config.playback.volume.min)
      @_player.openFile(resource)
      @_player.play()
      
      # Workaround as MPlayer has no decent error events. So what if internet connection is not available?
      # Check if playback started after 2 seconds, else play backup file
      setTimeout( ( () =>
        if !playing
          console.log('Unable to play: ' + resource)
          @stopAlarm()
          fs.access(@settings.config.playback.fallback, fs.constants.R_OK, (err) =>
            if err?
              console.log('Panic! Cannot open ' + @settings.config.playback.fallback + '. You are on your own now!')
            else
              console.log('Falling back to: ' + @settings.config.playback.fallback)
              @_playAudio(@settings.config.playback.fallback)
          )
        
        else
          console.log('Playback of ' + resource + ' started successfully...')
      ), 2000)
      
      interval = Math.round(@settings.config.playback.volume.increaseTimer / (@settings.config.playback.volume.max - @settings.config.playback.volume.min) * 1000)
      @_increaseVolume(interval)
    
    _increaseVolume: (interval) =>
      volume = @settings.config.playback.volume.min + 1
      @_player.volume(volume)
      
      autoIncrease = (volume) =>
        console.log(volume)
        @_player.volume(volume)
        
        volume += 1
        if volume <= @settings.config.playback.volume.max
          @_volIncrease = setTimeout(autoIncrease, interval, volume)
      @_volIncrease = setTimeout(autoIncrease, interval, volume)
    
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