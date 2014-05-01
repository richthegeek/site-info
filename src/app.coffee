async = require 'async'
express = require 'express'
cors = require 'cors'
mongo = require 'mongodb'
redis = require 'redis'

processor = require './processor'

getDatabase = async.memoize (callback) ->
	processor.attach mongo
	mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/siteinfo', (err, db) ->
		if err
			return callback err

		for collection in ['sites', 'maps', 'pages']
			db[collection] or= db.collection collection

		processor.setup db
		db.ensureWatcher {}, (err, set) ->
			callback null, db

getDatabase -> null

getRedis = async.memoize (callback) ->
	client = redis.createClient()
	client.subscribe 'domainUpdates'
	client.on 'message', (channel, message) ->
		client.emit 'updateDomain:' + message
	callback null, client

app = express()
app.use(cors())
app.use (req, res, next) ->
	getDatabase (err, db) ->
		req.db = db
		getRedis (err, redis) ->
			req.redis = redis
			next()

	req.times = [{name: 'Start', time: new Date}]
	req.time = (name) ->
		last = req.times[req.times.length - 1]
		t = new Date
		req.times.push x = {
			name: name,
			time: t
			total: t - req.times[0].time
			interval: t - last.time
		}
		return x

	writeHead = res.writeHead
	res.writeHead = () ->
		t = req.time 'Finished' 
		console.log req.method, req.originalUrl, "\t", t.total + 'ms'
		writeHead.apply res, arguments


app.use require('response-time')()

routes = require './routes'
for key, route of routes
	route(app)


app.listen 7483 # site