
module.exports = () ->
  
  EventsEmitter = require('events')
  express = require('express')
  
  class RestApi extends EventsEmitter
    
    constructor: () ->
      super()
    
    init: (port, @_settings) ->
      @_PORT = port || 3000
      @_httpServer = express()
      
      @_httpServer.use(express.json())
      @_httpServer.use(express.urlencoded({ extended: true }))
      
    getSmartHomeConfig: () =>
      return @_settings.config.smartHome
    
    getSchedule: () =>
      return @_settings.schedule.days
    
    getDay: (d) =>
      day = null
      @_settings.schedule.days.map( (item) =>
        day = item if d is item.id
      )
      return day
    
    getConfig: () =>
      return @_settings.config
    
    updateSchedule: (id, update) =>
      day = null
      dayIndex = null
      @_settings.schedule.days.map( (schedule, index) =>
        if schedule.id is id
          day = schedule
          dayIndex = index
      )
      return null if !day
      
      update.id        = id
      update.time     ?= day.time
      update.enabled  ?= day.enabled
      update.resource ?= day.resource
      
      @_settings.schedule.days.splice(dayIndex, 1, update)
      @_logUpdate(id, update)
      @_emitConfigUpdate()
      
      return update
    
    updateConfig: (id, update) =>
      success = true
      settings = @_settings.config[id]
      
      return null if !typeof(settings) is "object"
      
      for key, value of update
        do (key, value) =>
          if settings[key]?
            settings[key] = value
          else
            success = false
      
      return null if !success
      
      @_settings.config[id] = settings
      @_logUpdate(id, @_settings.config[id])
      @_emitConfigUpdate()
      
      return settings

    stopAlarm: () =>
      @emit('stopAlarm')
      return { response: "Alarm stopped" }
    
    activateAlarm: () =>
      resource = null
      today = @getTodayAsString()
      @_settings.schedule.days.map( (day) =>
        resource = day.resource if day.id is today
      )
      
      data = {
        response: 'Alarm activated',
        today,
        resource,
        endPoint: 'http://' + @_settings.config.smartHome.user + ':' + @_settings.config.smartHome.passwd + '@' + @_settings.config.smartHome.host + @_settings.config.smartHome.endPoint
      }
      @emit('activateAlarm', data)
      
      delete data.endPoint
      return data
    
    startServer: () =>
      
      @_settings.rest.map( (rest) =>
        status = 200
        if rest.http is "PUT"
          status = 201
        
        @_httpServer[rest.http.toLowerCase()]('/api' + rest.endPoint + rest.params, (req, res) =>
          res.status(status).send(@_restResponse(rest, req))
        )
      )
      console.log('API enabled.')
      @_httpServer.listen(@_PORT, () =>
        console.log('Server is running on PORT:',@_PORT)
      )
    
    _logUpdate: (item, update) ->
      console.log('Config update received:')
      console.log(item)
      console.log(update)
    
    _emitConfigUpdate: () =>
      @emit('configUpdated', @_settings)
    
    _restResponse: (rest, req) =>
      response = {
          success:  true
          message:  "success"
      }
      
      data = @[rest.method](req?.params?.id, req?.body)
      if !data?
        response.success = false
        response.message = "Error."
      else
        response.data = data
      
      return response
    
    getTodayAsString: () =>
      today = null
      
      date = new Date()
      @_settings.schedule.days.map( (day) =>
        if day.id is @_weekdays[date.getDay()]
          today = day.id
      )
      return today
    
    destroy: () ->
      super()
  
  return new RestApi