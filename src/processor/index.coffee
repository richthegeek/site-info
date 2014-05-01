module.exports = require '/home/richard/www/git/mtran-compiled/index'
module.exports.setup = (db) ->

	dns = require 'dns'
	async = require 'async'
	request = require 'request'
	redis = require 'redis'
	client = redis.createClient()

	getTitle = require './getTitle'
	getTags = require './getTags'
	getName = require './getName'
	getTech = require './getTech'

	db.sites or= db.collection 'sites'
	db.pages or= db.collection 'pages'

	# get the contents of the site and save it into the "pages" collection
	# from there it gets picked up for title and technology processing
	db.sites.watchAndProcess 'insert', {ops: ['insert', 'update'], query: {stale: true}}, (site, info, done) ->
		request = require 'request'

		db.sites.update {_id: site._id}, {$unset: stale: true}, (err1) ->
			db.pages.update {_id: {d: site._id, p: '/'}}, {$set: stale: true}, {upsert: true}, (err2) ->
				done err1 or err2
	
	db.sites.watchAndProcess 'dns', {ops: ['insert', 'update'], paths: ['stale']}, (site, info, done) ->
		dns.resolveIP = dns.resolve.bind(dns)
		fn = (name, done) ->
			dns['resolve' + name] site._id, (err, res) ->
				done null, [name, res or null]

		async.map ['IP', 'Mx', 'Txt', 'Srv', 'Ns', 'Cname'], fn, (err, result) ->
			combined = {}
			combined[row[0]] = row[1] for row in result
			db.sites.update {_id: site._id}, {$set: dns: combined}, done

	db.pages.watchAndProcess 'get', {ops: ['insert', 'update'], query: {stale: true}}, (page, info, done) ->
		domain = page._id.d
		path = page._id.p

		keys = Object.keys(page._id)
		if keys[0] isnt 'd' or keys[1] isnt 'p'
			# out-of-order ID, insert the other way round...
			console.log 'OOO'
			return db.pages.remove {_id: page._id}, () ->
				db.pages.insert {_id: {d: domain, p: path}, stale: true}, done

		db.sites.findOne {_id: domain}, {secure: 1}, (err, site) ->
			protocol = (if site.secure then 'https' else 'http')
			url = protocol + '://' + domain + path

			start = new Date
			request url, (err, resp, body) ->
				if err
					console.log 'ERR', url, err
				if not body
					console.log 'No body', url
					return done()

				# lowercase headers
				headers = {}
				for key, val of resp.headers
					headers[key.toLowerCase()] = val

				body = body.toString()
				# assume HTML
				headers['content-type'] ?= 'text/html'
				
				$set =
					date: new Date
					time: new Date - start
					size: Buffer.byteLength(body, 'utf8')
					status: resp.statusCode
					headers: headers

				if headers['content-type'] is 'text/html'
					$set.body = body
					$set.type = 'html'
				else
					$set.type = headers['content-type'].split('/').shift()
				
				$unset = stale: 1
				db.pages.update {_id: page._id}, {$set, $unset}, {upsert: true}, done

	db.pages.watchAndProcess 'parse', {ops: ['update'], paths: ['body']}, (doc, info, done) ->
		if not doc.body
			return done()

		url = require 'url'
		parse = url.parse
		addUnique = (target, text) -> target.push(text) if text not in target
		links = getTags(doc.body, 'a')
			.map((link) -> link.href)
			.filter(Boolean)
			.map(parse)
			.filter((link) -> link and link.path)
			.reduce((obj, link) ->
				link.host or= doc._id.d
				if link.host is doc._id.d
					addUnique obj.internal, url.resolve doc._id.p, link.path
				else
					addUnique obj.external, link.protocol + '//' + link.host + link.path

				return obj
			, {internal: [], external: []})

		$set =
			title: getTitle doc.body
			name: getName doc.body, doc._id.d
			links: links
			tech: getTech doc

		if doc._id.p is '/'
			db.sites.update {_id: doc._id.d}, {$set}, -> null

		db.pages.update {_id: doc._id}, {$set}, ->
			update = (path, next) ->
				id = {d: doc._id.d, p: path}
				db.pages.insert {_id: id, stale: true}, (err, insert) ->
					next()

			async.each links.internal, update, done
