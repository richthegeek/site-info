module.exports = (body, tag) ->
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