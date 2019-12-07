#!/usr/bin/env node
require('coffee-cache').setCacheDir('.jscache/');

var Application = require('./lib/application');
var app = new Application();