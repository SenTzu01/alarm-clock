fs = require('fs')
express = require('express');
app = express()
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

PORT = 3000;

# Enable RESTful GET schedule for each day
settings = require('../config.json')


app.get("/api/settings", (req, res) =>
  res.status(200).send({
    success: 'true',
    message: 'settings retrieved successfully',
    settings: settings
  })
)

# Enable RESTful UPDATE schedule for selected day
app.put("/api/:id", (req, res) =>
  id = req.params.id
  day = false
  dayIndex = false
  
  
  settings.map( (settings, index) =>
    if settings.id is id
      day = settings
      dayIndex = index
  )
  
  if !day
    return res.status(404).send({
      success: 'false',
      message: 'day not found'
    })
  
  updatedDay = {
    id: day.id,
    time: req.body.time || day.time,
    enabled: req.body.enabled || day.enabled,
    resource: req.body.resource || day.resource,
    endpoint: req.body.endpoint || day.endpoint
  }
  
  settings.splice(dayIndex, 1, updatedDay)
  
  fs.writeFile('./config.json', JSON.stringify(settings, null, 2), (err) =>
    if err?
      console.log('Error writing config:' + err)
  )
  
  return res.status(201).send({
    success: true,
    message: 'config updated successfully'
    updatedDay
  })
  
)


app.listen(PORT, () =>
  console.log('Server is running on PORT:',PORT)
)