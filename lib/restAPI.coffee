  EventsEmitter = require('events')
  Express = require('express')
  
  class RestApi extends EventsEmitter
    
    constructor: (@_httpServer, @_rest) ->
      super()
      @_httpServer.use(Express.json())
      @_httpServer.use(Express.urlencoded({ extended: true }))
      @_callbacks = {}
    
    smartHome: (config) =>
      @_ha = config
      return @
    
    playback: (config) =>
      @_playback = config
      return @
    
    schedule: (config, cb) =>
      @_schedule = config
      @_callbacks.schedule = cb
      return @
    
    config: (config, cb) =>
      @_config = config
      @_callbacks.config = cb
      return @
    
    startServer: (port) =>
      
      @_rest.map( (rest) =>
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
      return @_ha if @_ha?
      return null
    
    getPlayback: () =>
      return @_playback if @_playback?
      return null
    
    getSchedule: () =>
      return @_schedule if @_schedule?
      return null
    
    getDay: (d) =>
      return null if !@_schedule?.days?
      
      day = null
      @_schedule.days.map( (item) =>
        day = item if d is item.id
      )
      return day
    
    updateSchedule: (id, update) =>
      day = null
      dayIndex = null
      @_schedule.map( (item, index) =>
        if item.id is id
          day = item
          dayIndex = index
      )
      return null if !day
      
      update.id        = id
      update.time     ?= day.time
      update.enabled  ?= day.enabled
      update.resource ?= day.resource
      
      @_schedule.splice(dayIndex, 1, update)
      @_callbacks.schedule(@_schedule)
      @_logUpdate(id, update)
      
      return update
    
    updateConfig: (id, update) =>
      success = false
      settings = @_config[id]
      return null if !typeof(settings) is "object"

      recurse = (config, update) =>
        for prop of config
          do (prop) =>
            if Object.hasOwnProperty.call(config, prop) && Object.hasOwnProperty.call(update, prop)
              if typeof(config[prop]) is "object" && typeof(update[prop]) is "object"
                recurse(config[prop], update[prop])
              else
                success = true
                config[prop] = update[prop]
        return config
      recurse(settings, update)

      return null if !success
      
      @_config[id] = settings
      @_callbacks.config(@_config)
      @_logUpdate(id, @_config[id])
      
      return settings
    
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
  
  module.exports = RestApi