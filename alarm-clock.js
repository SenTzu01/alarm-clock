#!/usr/bin/env node
command = process.argv[2];
require('console-stamp')(console);
if(!command || command === "start") {
  require('./coffee-cache.js').setCacheDir('.jscache/');
  console.log('Alarm Clock starting...')
  
  var Application = require('./lib/application');
  var app = new Application();
  var exitCode = 0;
  
  terminate = function() {
    console.log('Shutting down alarm-clock...');
    app.destroy().then( () => {
      console.log('Stopped.');
      
    }).catch( (error) => {
      console.error(error);
      exitCode = 1;
    
    }).finally( () => {
      process.exit(exitCode);
    });
  }
  process.on('SIGINT', terminate)
  process.on('SIGTERM', terminate)
  
}