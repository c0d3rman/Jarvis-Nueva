coffeecup = require 'coffeecup'
coffeemiddleware = require 'coffee-middleware'
express = require 'express'
morgan = require 'morgan'
servestatic = require 'serve-static'
fs = require 'fs'
path = require 'path'
http = require 'http'
https = require 'https'
edt = require 'express-directory-traversal'
cluster = require 'cluster'
os = require 'os'
proxy = require 'express-http-proxy'
url = require 'url'

eggs = require './eastereggs'


numCPUs = os.cpus().length

if cluster.isMaster
	console.log "Jarvis initialized"
	for i in [1..numCPUs]
		cluster.fork() 
		console.log "Process #{i} started"
	cluster.on "exit", (worker, code, signal) -> cluster.fork()
else
	`
	var compile = function (fmt) {
		fmt = fmt.replace(/"/g, '\\"');
		var js = '  return "' + fmt.replace(/:([-\w]{2,})(?:\[([^\]]+)\])?/g, function(_, name, arg){
		        return '"\n    + (tokens["' + name + '"](req, res, "' + arg + '") || "-") + "';
		}) + '";'
		return new Function('tokens, req, res', js);
	};
	`

	morgan.format 'dev++', (tokens, req, res) ->
		color = 32
		status = res.statusCode
	
		if status >= 500 then color = 31
		else if status >= 400 then color = 33
		else if status >= 300 then color = 36
	
		fn = compile "\x1b[90m:remote-addr \x1b[32m:method \x1b[35m:url \x1b[" + color + "m:status \x1b[97m:response-time ms\x1b[0m"
	
		fn tokens, req, res

	errorHandler = (err, req, res, next) ->
		res.status(500).send 'Server error'
		
	proxyParser = (req, res) ->
		console.log req.params.query
		req.params.query
	

	app = express()

	app.set 'views', "#{__dirname}/webroot"
	app.set 'view engine', 'coffee'
	app.engine 'coffee', coffeecup.__express

	app.use morgan "combined", stream: {write: (str) -> fs.appendFileSync "#{__dirname}/log/long.log", str}
	app.use morgan "dev++", stream: {write: (str) -> fs.appendFileSync "#{__dirname}/log/short.log", str}
	app.use edt "Yo dawg, I heard you liked paths so I put paths in your paths so you can traverse paths while you're traversing paths.\n"
	app.use coffeemiddleware src: "#{__dirname}/webroot"
	app.use servestatic "#{__dirname}/webroot"
	app.use errorHandler
	
	app.get '/', (req, res) ->
		res.render 'index', empty: ''
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
	app.get '/eastereggs/:egg', (req, res) ->
		egg = req.params.egg
			.toLowerCase()
			.replace /[^a-z ]/g, ""
		if eggs[egg]?
			res.end eggs[egg]
		else
			res.end ""
	app.get '/proxy/google/:query', proxy 'https://google.com', proxyParser
	app.get '/proxy/wolfram/:query', proxy 'https://wolframalpha.com', proxyParser
	app.get '/proxy/yahoo/:query', proxy 'https://yahoo.com', proxyParser
	app.get '/carter', (req, res) ->
		res.redirect "http://73.162.155.107"
	app.get '*', (req, res) ->
		relpath = "#{req.url.substr(1)}index"
		filepath = "#{__dirname}/webroot#{req.url}index.coffee"
		if filepath isnt path.join '/', filepath
			res.writeHead 403, "Content-Type": "text/plain"
			res.write "The directory traversal is strong in this one."
			res.end()
		else
			fs.exists filepath, (fileExists) ->
				if fileExists
					res.render relpath, empty: ''
				else
					res.status 404
					if req.accepts 'html'
						res.render '404', empty: ''
					else
						res.write '404 not found'
						res.end()
	
	options =
		ca: [
			fs.readFileSync("#{__dirname}/certs/ca.pem", 'utf8'),
			fs.readFileSync "#{__dirname}/certs/sub.class1.server.ca.pem", 'utf8'
		]
		key: fs.readFileSync "#{__dirname}/certs/server.key"
		cert: fs.readFileSync "#{__dirname}/certs/server.crt"

	wwwdata = ->
		process.setgid "www-data"
		process.setuid "www-data"
	localhost = "0.0.0.0"

	httpServer = http.createServer (req, res) ->
		res.writeHead 301, "Content-Type": "text/plain", "Location": "https://#{req.headers.host + req.url}"
		res.end()
	httpsServer = https.createServer options, app
	httpServer.listen 80, localhost, wwwdata
	httpsServer.listen 443, localhost, wwwdata
