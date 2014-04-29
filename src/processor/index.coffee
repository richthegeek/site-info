module.exports = require '/home/richard/www/git/mtran-compiled/index'
module.exports.setup = (db) ->
	db.sites or= db.collection 'sites'
	db.content or= db.collection 'content'

	# get the contents of the site and save it into the "content" collection
	# from there it gets picked up for title and technology processing
	db.sites.watchAndProcess 'insert', {ops: 'insert'}, (site, info, done) ->
		request = require 'request'

		start = new Date
		request site._id, (err, resp, body) ->
			end = new Date
			db.content.update {_id: site._id}, {
				_id: site._id,
				date: new Date
				time: end - start,
				status: resp.statusCode
				headers: resp.headers
				body: body or err
			}, {upsert: true}, (err) ->
				done err
	
	redis = require 'redis'
	client = redis.createClient()
	db.sites.watchAndProcess 'publish', {ops: 'update', load: false}, (site, info, done) ->
		client.publish 'domainUpdates', site._id
		done()
	
	getName = require './getName'
	getTech = require './getTech'
	db.content.watchAndProcess 'content', {ops: ['insert', 'update']}, (doc, info, done) ->
		set =
			name: getName doc.body, doc._id
			tech: getTech doc
			speed: doc.time / 1000

		db.sites.update {_id: doc._id}, {$set: set}, ->
			done()