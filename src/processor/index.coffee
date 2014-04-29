module.exports = require '/home/richard/www/git/mtran-compiled/index'
module.exports.setup = (db) ->

	dns = require 'dns'
	async = require 'async'
	redis = require 'redis'
	client = redis.createClient()

	getTitle = require './getTitle'
	getName = require './getName'
	getTech = require './getTech'

	db.sites or= db.collection 'sites'
	db.content or= db.collection 'content'

	# get the contents of the site and save it into the "content" collection
	# from there it gets picked up for title and technology processing
	db.sites.watchAndProcess 'insert', {ops: ['insert', 'update'], query: {stale: true}}, (site, info, done) ->
		request = require 'request'

		db.sites.update {_id: site._id}, {$set: stale: false}, -> null

		start = new Date
		request site._id, (err, resp, body) ->
			if err
				return db.sites.update {_id: site._id}, {$set: {
					error: 'Not Found'
				}}, done

			end = new Date
			db.content.update {_id: site._id}, {
				_id: site._id,
				date: new Date
				time: end - start,
				status: resp.statusCode
				headers: resp.headers
				body: body
			}, {upsert: true}, (err) ->
				done err
	
	db.sites.watchAndProcess 'dns', {ops: 'insert', load: false}, (site, info, done) ->
		url = site._id.replace(/(https?:\/\/)(www.\.)?/, '').split('/').shift()
		
		dns.resolveIP = dns.resolve.bind(dns)
		fn = (name, done) ->
			dns['resolve' + name] url, (err, res) ->
				o = {}
				o[name] = res or null
				return done null, o

		async.map ['IP', 'Mx', 'Txt', 'Srv', 'Ns', 'Cname'], fn, (err, result) ->
			combined = {}
			for row in result
				for key, val of row
					combined[key] = val

			set = dns: combined
			db.sites.update {_id: site._id}, {$set: set}, done

	db.content.watchAndProcess 'content', {ops: ['insert', 'update']}, (doc, info, done) ->
		if doc.body
			set =
				title: getTitle doc.body
				name: getName doc.body, doc._id
				tech: getTech doc
				size: parseFloat (Buffer.byteLength(doc.body.toString(), 'utf8') / 1024).toString().substr(0, 5)

		else if doc.status.toString().charAt(0) isnt '2'
			set =
				title: doc.status + ' ' + http.STATUS_CODES[doc.status]

		set.speed = doc.time / 1000
		db.sites.update {_id: doc._id}, {$set: set}, ->
			client.publish 'domainUpdates', doc._id, -> null
			
			done()