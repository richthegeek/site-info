module.exports = (input) ->
	wapp = require './wappalyzer'
	getTags = require './getTags'

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
	categories = []
	versions = {}
	setDetected = (name, type, pattern, match) ->
		if pattern.version
			console.log name, pattern, match

		if pattern.version and version = match.match pattern.regex
			for ver in version when m = ver?.match? /^\s*([1-9]?[0-9](\.[0-9]+)*)\s*$/
				versions[name] = m[1]
		
		if name not in detected
			detected.push name
			def = wapp.apps[name]

			if def.cats
				for cat in def.cats when cname = wapp.categories[cat]
					if cname not in categories
						categories.push cname

			if def.implies
				if 'string' is typeof defs.implies
					defs.implies = [defs.implies]
				defs.implies.forEach setDetected

	metas = getTags input.body, 'meta'
	scripts = getTags input.body, 'script'

	for name, defs of wapp.apps

		if def = defs.env
			# we can't do env stuff because we dont run a headless webkit.
			null

		if def = defs.headers
			for header, value of def
				parse(value).forEach (pattern) ->
					for k2, v2 of input.headers when header.toLowerCase() is k2.toLowerCase()
						if pattern.regex.test v2
							setDetected name, 'headers', pattern, v2

		if def = defs.meta
			for meta in metas when patterns = def[meta.name]
				parse(patterns).forEach (pattern) ->
					if pattern.regex.test meta.content
						setDetected name, 'meta', pattern, meta.content

		if def = defs.script
			for script in scripts when src = script.src
				parse(def).forEach (pattern) ->
					if pattern.regex.test src
						setDetected name, 'script', pattern, src

		if def = defs.html
			parse(defs.html).forEach (pattern) ->
				if m = pattern.regex.exec input.body
					setDetected name, 'html', pattern, m[0]

	return {
		list: detected
		versions: versions
		categories: categories
	}