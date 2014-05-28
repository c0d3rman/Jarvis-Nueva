coffeecup = require 'coffeecup'
coffeemiddleware = require 'coffee-middleware'
express = require 'express'
morgan = require 'morgan'
servestatic = require 'serve-static'
fs = require 'fs'
path = require 'path'
http = require 'http'
https = require 'https'
busboy = require 'connect-busboy'
#subdomains = require 'express-subdomains'
storage = require 'node-persist'


storage.initSync()

#subdomains.use 'u'
#need updated certificate for subdomain

app = express()

app.set 'views', "#{__dirname}/webroot"
app.set 'view engine', 'coffee'
app.engine 'coffee', coffeecup.__express

app.use morgan 'dev'
#app.use subdomains.middleware
app.use (req, res, next) ->
	decoded = decodeURIComponent req.url
	if decoded isnt path.join '/', decoded
		res.writeHead 403, "Content-Type": "text/plain"
		res.write "Yo dawg, I heard you liked paths so I put paths in your paths so you can traverse paths while you're traversing paths.\n"
		res.end()
	else
		next()
app.use coffeemiddleware src: "#{__dirname}/webroot"
app.use busboy fileSize: 20 * 1024 * 1024
app.use servestatic "#{__dirname}/webroot"

helpers = {}
helpers["_#{f.slice 0, -7}"] = require "./include/#{f}" for f in fs.readdirSync('./include') when f.slice(-7) is ".coffee"

app.get '/', (req, res) ->
	res.render 'index', empty: '', hardcode: helpers
app.get '/u/:short', (req, res) ->
	if storage.getItem(req.params.short)?
		res.redirect storage.getItem req.params.short
	else
		res.end 'No url here :-('	
app.get '/u/:short/:long', (req, res) ->
	storage.setItem req.params.short, "http://" + decodeURIComponent req.params.long
	res.end "https://jarvispa.info/u/#{req.params.short}  ->  #{decodeURIComponent req.params.long}"
app.get '/resources/userMusic', (req, res) ->
	fs.readdir "#{__dirname}/webroot/resources/userMusic", (err, files) ->
		if err
			res.writeHead 500, "Content-Type": "text/plain"
			res.write "Internal error fetching music list"
			res.end()
			console.log err.message
		else
			res.writeHead 200, "Content-Type": "text/plain"
			res.write "#{file}\n" for file in files
			res.end()
app.post '/upload', (req, res) ->
	req.pipe req.busboy
	req.busboy.on 'file', (fieldname, file, filename) ->
		filename = filename.replace(RegExp(' ', 'g'), '_').replace(/[^A-Z0-9._-]/ig, '').toLowerCase()
		filepath = "#{__dirname}/webroot/resources/userMusic/#{filename}"
		if filepath isnt path.join '/', filepath
			res.writeHead 403, "Content-Type": "text/plain"
			res.write "The directory traversal is strong in this one."
			res.end()
		else
			fstream = fs.createWriteStream filepath
			file.pipe fstream
			fstream.on 'close', ->
				#fs.chownSync filepath, 33, 33
				#fs.chmodSync filepath, 700
				res.writeHead 200
				res.write "File uploaded successfuly"
				res.end()
app.get '*', (req, res) ->
	res.status 404
	if req.accepts 'html'
		res.render '404', empty: '', hardcode: helpers
	else
		res.write '404 not found'
		res.end()

options =
	key: fs.readFileSync "#{__dirname}/certs/server.key"
	cert: fs.readFileSync "#{__dirname}/certs/server.crt"

wwwdata = -> process.setuid "www-data"
localhost = "0.0.0.0"

httpServer = http.createServer (req, res) ->
	res.writeHead 301, "Content-Type": "text/plain", "Location": "https://#{req.headers.host + req.url}"
	res.end()
httpsServer = https.createServer options, app
httpServer.listen 80, localhost, wwwdata
httpsServer.listen 443, localhost, wwwdata

console.log "Jarvis initialized"
