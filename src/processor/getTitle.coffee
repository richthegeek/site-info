module.exports = (body) ->
	return body.match('<title>(([\r\n\s]|.)*?)</title>')[1]