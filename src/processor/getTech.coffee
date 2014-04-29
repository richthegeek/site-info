module.exports = (input) ->
	wapp = require './wappalyzer'

	parse = (patterns) ->
		if 'string' is typeof patterns
			patterns = [patterns]

		return patterns.map (pattern) ->
			attrs = {}
			pattern.split('\\;').forEach (attr, i) ->
				if i
					if (attr = attr.split ':').length > 1
						attrs[attr.shift()] = attr.join ':'
				else
					attrs.string = attr
					try
						attrs.regex = new RegExp attr.replace('/', '\/'), 'i'
					catch
						attrs.regex = new RegExp()
			return attrs

	detected = []
	setDetected = (name, pattern) ->
		if name not in detected
			detected.push name

			defs = wapp.apps[name]
			if defs.implies
				if 'string' is typeof defs.implies
					defs.implies = [defs.implies]
				defs.implies.forEach setDetected

	extractTags = (body, tag) ->
		regex = new RegExp '<' + tag + '[^>]+>', 'ig'
		propReg = new RegExp /([a-z]+)=('|")([^'"]+)\2/i
		tags = []
		while tag = regex.exec body
			tag = tag[0]
			obj = {}
			while prop = tag.match propReg
				tag = tag.replace prop[0], ''
				obj[prop[1]] = prop[3]
			tags.push obj
		return tags

	for name, defs of wapp.apps

		# if def = defs.env
		# 	console.log 'skip env'

		if def = defs.headers
			hnames = Object.keys(input.headers).map((v) -> v.toLowerCase())
			for header, value of def
				parse(value).forEach (pattern) ->
					for k2, v2 of input.headers when header.toLowerCase() is k2.toLowerCase()
						if pattern.regex.test v2
							setDetected name, pattern

		if def = defs.meta
			metas = extractTags input.body, 'meta'
			
			for meta in metas when patterns = def[meta.name]
				parse(patterns).forEach (pattern) ->
					if pattern.regex.test meta.content
						setDetected name, pattern

		if def = defs.script
			scripts = extractTags input.body, 'script'

			for script in scripts when src = script.src
				parse(def).forEach (pattern) ->
					if pattern.regex.test src
						setDetected name, pattern

		if def = defs.html
			parse(defs.html).forEach (pattern) ->
				if pattern.regex.test input.body
					setDetected name, pattern

	return detected