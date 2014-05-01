url = require 'url'
module.exports = (app) ->

	app.route('/map').get (req, res, next) ->
		domain = req.query.domain
		refresh = req.query.refresh?

		if not domain.match /^https?:\/\//
			domain = "http://" + domain

		parse = url.parse(domain)

		if not (parse.host? and parse.protocol?)
			return res.json {err: 'Invalid URL'}

		domain = parse.host

		query = {_id: domain}
		req.db.maps.findOne query, (err, info) ->
			if err
				return next err

			if info and not refresh
				return next null, res.json info

			$set =
				secure: parse.protocol is 'https:'
				pages: ['/']

			# return a faked .maps result
			info = 
				_id: domain,
				stale: true,
				secure: $set.secure
				pages: $set.pages

			req.db.maps.update query, {$set}, {upsert: true}, (err1) ->
				$set = stale: true
				req.db.pages.update {_id: {d: domain, p: '/'}}, {$set}, {upsert: true}, (err2) ->
					next (err1 or err2), res.json info