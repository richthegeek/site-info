url = require 'url'
module.exports = (app) ->

	app.route('/info').get (req, res, next) ->
		domain = req.query.domain
		timeout = Math.max 0, Math.min 30, Number(req.query.timeout ? 5)
		refresh = req.query.refresh?

		parse = url.parse(domain)

		if not (parse.host? and parse.protocol?)
			return res.json {err: 'Invalid URL'}

		domain = parse.href

		send = (err, info) ->
			if err
				res.json {err: err.message or err}
				return true
			else if info
				req.time 'Sent'
				res.json info
				return true
			return false

		findSite = (callback) ->
			req.db.sites.findOne {_id: domain}, (err, info) ->
				if err
					return send err
				else
					callback null, info

		awaitName = (fallback) ->
			listener = () ->
				listener = -> null
				findSite send
			event = 'updateDomain:' + domain
			req.redis.once event, listener

			setTimeout(() ->
				req.redis.removeListener event, listener
				listener()
			, timeout * 1000)

		findSite (err, info) ->
			if refresh
				info = null

			if info?.name?
				return send null, info

			req.time 'Found'
			if not info
				req.db.sites.update {_id: domain}, {$set: stale: true}, {upsert: true}, (err) ->
					if err
						return send err

					req.time 'Inserted'
					awaitName()
			else
				awaitName()
