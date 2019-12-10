#!/usr/bin/env node
require('console-stamp')(console);
require('./coffee-cache.js').setCacheDir('.jscache/');
var Application = require('./lib/application');
console.log('Application starting...')
var app = new Application();