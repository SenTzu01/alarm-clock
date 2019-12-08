# Alarm clock
WORK IN PROGRESS

## Smart Alarm clock application
* Coffeescript on NodeJS
* Runs on a webserver
* Exposes REST API (To be documented, but config-default.json is rather self-explaining) Default is http://\<host\>:3000/api/<endpoints>
* Maintains recurring schedule for all weekdays, with attributes per day for audio resource, enabled/disabled, and wake-up time
* Able to trigger a Smart home server via its REST interface (Currently focussed on Pimatic)

To install, clone the repo, and copy config-default.json to config.json, and edit details for home automation server. Run npm install from within the project dir

More/Better documentation will follow.
To do / Requested: UI / UX skilled person to create a fancy front end to interface with the REST API
