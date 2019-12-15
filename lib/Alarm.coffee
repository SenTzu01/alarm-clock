  fs = require('fs')
  Mplayer = require('mplayer')
  
  class Alarm
    constructor: (opts) ->
      @_volumeMin = opts?.volumeMin || 0
      @_volumeMax = opts?.volumeMax || 50
      @_localFile = opts?.localFile || null
      @_increaseTimer = opts?.increaseTimer || 60
      
      @_mplayer = new Mplayer()
    
    range: (min, max) =>
      @_volumeMin = min if min?
      @_volumeMax = max if max?
      return @
    
    timer: (seconds) =>
      @_increaseTimer = seconds if seconds?
      return @
    
    volume: (volume) =>
      @_mplayer.volume(volume)
      console.log('Volume set to: ' + volume)
      return @
    
    localAudio: (file) =>
      @_localFile = file
      return @
    
    start: (resource) =>
      @_playAudio(resource)
    
    stop: () =>
      @_mplayer.stop()
      @_mplayer.removeAllListeners('status')
      clearTimeout(@_volIncrease)
      console.log('Alarm stopped')
    
    _playAudio: (resource) =>
      playing = false
      @_mplayer.once('start', () => playing = true )
      @_mplayer.stop()
      @_mplayer.volume(@_volumeMin)
      @_mplayer.openFile(resource)
      @_mplayer.play()
      
      # Workaround as MPlayer has no decent error events. So what if internet connection is not available?
      # Check if playback started after 2 seconds, else play backup file
      setTimeout( ( () =>
        if !playing
          console.log('Unable to play: ' + resource)
          @stop()
          fs.access(@_localFile, fs.constants.R_OK, (err) =>
            if err?
              console.log('Panic! Cannot open ' + @_localFile + '. You are on your own now!')
            else
              console.log('Falling back to: ' + @_localFile)
              @_playAudio(@_localFile)
          )
        
        else
          console.log('Playback of ' + resource + ' started successfully...')
      ), 2000)
      
      interval = Math.round(@_increaseTimer / (@_volumeMax - @_volumeMin) * 1000)
      @_increaseVolume(interval)
    
    _increaseVolume: (interval) =>
      volume = @_volumeMin + 1
      @_mplayer.volume(volume)
      
      autoIncrease = (volume) =>
        console.log(volume)
        @_mplayer.volume(volume)
        
        volume += 1
        if volume <= @_volumeMax
          @_volIncrease = setTimeout(autoIncrease, interval, volume)
      @_volIncrease = setTimeout(autoIncrease, interval, volume)
    
    destroy: () ->
      @_mplayer.removeAllListeners('status')
  
  module.exports = Alarm