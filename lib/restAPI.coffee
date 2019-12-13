module.exports = () ->
  
  EventsEmitter = require('events')
  express = require('express')
  
  class RestApi extends EventsEmitter
    
    constructor: () ->
      super()
    
    init: (@_httpServer, @_settings) ->
      @_httpServer.use(express.json())
      @_httpServer.use(express.urlencoded({ extended: true }))
    
    startServer: (port) =>
      
      @_settings.rest.map( (rest) =>
        status = 200
        if rest.http is "PUT"
          status = 201
        
        @_httpServer[rest.http.toLowerCase()]('/api' + rest.endPoint + rest.params, (req, res) =>
          res.status(status).send(@_restResponse(rest, req))
        )
      )
      console.log('API enabled.')
      @_httpServer.listen(port, () =>
        console.log('Server is running on PORT:', port)
      )
    
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
    
    setVolume: (id, params) =>
      return null if typeof(params.value) != "number" || params.value > @_settings.config.volume.max || params.value < @_settings.config.volume.min
      
      @emit('setVolume', params.value)
      return @_responseObject("Volume set")
    
    toggleAlarm: (id, params) =>
      return @_activateAlarm(params) if id is "start"
      return @_stopAlarm(params)
    
    _stopAlarm: (params) =>
      return null if typeof(params) != "object"
      
      @emit('stopAlarm')
      return @_responseObject("Alarm stopped")
    
    _activateAlarm: (params) =>
      return null if typeof(params.resource) != 'string' or typeof(params.triggerSmartHome) != 'boolean'
      
      @emit('activateAlarm', params)
      return @_responseObject("Alarm activated")
    
    _logUpdate: (item, update) ->
      console.log('Config update received:')
      console.log(item)
      console.log(update)
    
    _emitConfigUpdate: () =>
      @emit('configUpdated', @_settings)
    
    _responseObject: (response) ->
      return { response }
    
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
    
    destroy: () ->
      super()
  
  return new RestApi