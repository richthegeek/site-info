module.exports = (body, url) ->
	title = body.match('<title>(([\r\n\s]|.)*?)</title>')[1]

	trim = (v) -> v.replace(/(^\s+|\s+$)/, '')

	if tld = url.match /([^\.\/]+)\.((com?|org|edu|ac)\.)?([a-z]{2,6})(\/.+)?$/
		tld = tld[1].replace /[^\d\w]+/, ''
		
	if title
		words = title.split /(\&.+?;|,|\.|-|[^\w\d]+)\s/
		if tld
			pattern = new RegExp '^\\s*' + tld.split('').map((v) -> v + '\\s?').join('') + '.*\s*', 'i'
			matched = words.map(pattern.exec.bind(pattern))
			
			if (passed = matched.filter(Array.isArray).shift()) and passed.length > 0
				return trim passed[0]

		uppercase = words.filter((word) -> word.charAt(0).toUpperCase() is word.charAt(0))
		if uppercase.length > 0
			# todo: filter again by capitalised (Hacker News vs Some thing)
			return trim uppercase[0]

		return trim words[0]

	return trim tld