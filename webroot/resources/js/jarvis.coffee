$(document).ready ->
	# define jarvis object for others to interact with
	jarvis =
		birthday: moment "2014-05-06T01:35:48.000Z"
		swearWords: jQuery.ajax url: '/resources/data/swearWords.json', dataType: "json", success: (json) -> window.jarvis.swearWords = json
		# add a talk fuction to submit messages to terminal
		talk: (message, {speaker, phonetic, noprint} = {}) ->
			speaker ?= "Jarvis" 						# speaker default is "Jarvis"
			message = message
				.replace(/<(?:.|\n)*?>/gm, '')			# remove HTML
				.replace /[^A-Z0-9!.?:;,\s'"-]/ig, ''	# zap gremlins'
			phonetic ?= message 			# phonetic default is the message
		
			phonetic = phonetic.split /\n/	# make new lines into their own utterances
			
			if not noprint
				$("#terminalContent").append $("<p></p>").text(speaker + ': ' + message)
			
				offscreen = $("#terminalContent").children(":offscreen").length
				$("#terminalContent").children().slice(0, offscreen).fadeOut -> this.remove()
			
				$(document).profanityFilter customSwears: this.swearWords or {}
			
			if speaker == "Jarvis"
				if speechSynthesis?
					for line in phonetic
						message = new SpeechSynthesisUtterance line
						message.voice = speechSynthesis.getVoices().filter((voice) -> voice.name == 'Google UK English Male')[0]
						message.lang = "en-GB"
						message.onend = (event) ->
							window.jarvis.queue.shift()
							speechSynthesis.cancel()
							speechSynthesis.speak window.jarvis.queue[0] if window.jarvis.queue[0]?
						this.queueUp message
				else
					#speak phonetic.join("\n"), {pitch: 20}
					console.log "Text to speech not supported"
		# handle utterance queueing
		queue: []
		queueUp: (message) ->
			this.queue.push message
			if this.queue.length is 1
				speechSynthesis.cancel()
				speechSynthesis.speak message
		
		randpick: (choices) ->
			this.talk choices[Math.floor(Math.random() * choices.length)]
			
		ajaxFailure: (jqXHR, textStatus, errorThrown) ->
			console.log 'textStatus: ' + textStatus
			console.log 'errorThrown: ' + errorThrown
			console.log 'jqXHR: ' + jqXHR
			if not navigator.onLine
				window.jarvis.talk "I can't connect to the internet", phonetic: "I cant connect to the internet"
				throw errorThrown
			else if textStatus is 'timeout'
				mixpanel.track "timeout"
				window.jarvis.talk "I'm having trouble connecting with my servers", phonetic: "I am having trouble connecting with my servers"
			else
				window.jarvis.failGracefully -> throw errorThrown
		
		process: (command) ->
			this.failGracefully ->
				this.actions._easteregg this, command, ->
					$.ajax
						url: "https://api.wit.ai/message"
						data:
							'v': '20150427' #April 7th 2015
							'q': command
							'access_token': apiKeys.witai
						dataType: "jsonp"
						jsonp: "callback"
						method: "POST"
						timeout: 1000
					.done (data) ->
						confidence = data.outcomes[0].confidence
						if confidence > 0.6
							window.jarvis.understand data
						else
							window.jarvis.actions._unknown(window.jarvis)
					.fail this.ajaxFailure
					.retry times: 3, timeout: 5000
				
		understand: (rawData) ->
			this.failGracefully ->
				intent = rawData.outcomes[0].intent
				data = rawData.outcomes[0].entities
				data._text = rawData._text
				mixpanel.track intent
				(this.actions[intent] or this.actions._unknown)(this, data)
		
		actions:
			age:		(self) ->
				self.talk "I was created #{self.birthday.fromNow()}"
			birthday:	(self) ->
				self.talk "I was created on #{self.birthday.format 'MMMM Do, YYYY'}"
			calculate:	(self, data) ->
				expression = data.math_expression[0].value
				self.talk "Calculating #{expression}"
				window.open "http://www.wolframalpha.com/input/?i=#{encodeURIComponent expression}", "_self"
			caltrain: (self, data) ->
				origin = data.origin?[0].value
				destination = data.destination?[0].value
				direction = data.direction?[0].value
				origin = "Hillsdale" if origin is "Here"
				destination = "Hillsdale" if destination is "Here"
				# if no stations were given whatsoever, give up
				if not origin? and not destination?
					self.talk "Please tell me which stations you want to take the train to and from.", phonetic: "Please tell me which stations you want to take the train to, and froam."
				# if only an origin was given, report the first train to arrive at that origin
				else if not destination?
					jQuery.ajax url: "https://caltrain-realtime.herokuapp.com/api/#{origin}",
						dataType: "json",
					.done (do (direction) -> (json) -> # closure to pass in the direction variable
						train.direction = "north" for train in json.northbound # mark all northbound trains
						train.direction = "south" for train in json.southbound # mark all southbound trains
						getFirstTrain = (trainlist) -> (trainlist.sort (train1, train2) -> parseInt(train2.minutesUntilDeparture) - parseInt(train2.minutesUntilDeparture))[0]
						if direction?
							trains = []
							if direction is "North"
								trains = json.northbound
							else if direction is "South"
								trains = json.southbound
							firstTrain = getFirstTrain trains
							window.jarvis.talk "The next #{firstTrain.direction}bound train to arrive at #{origin} is train #{firstTrain.trainNumber}.
It will arrive in #{firstTrain.minutesUntilDeparture} minutes."
						else
							trains = json.northbound.concat json.southbound
							firstTrain = getFirstTrain trains
							window.jarvis.talk "The next train to arrive at #{origin} is train #{firstTrain.trainNumber}.
It will arrive in #{firstTrain.minutesUntilDeparture} minutes and is #{firstTrain.direction}bound."
					)
					.fail this.ajaxFailure
					.retry times: 3, timeout: 5000
				# otherwise, default origin to Hillsdale and find first train from origin to destination
				else
					self.talk "Not yet supported"
			class_end:	(self) ->
				if window.scheduleUtils.getCurrentClass()?
					[day, time] = window.scheduleUtils.getCurrentTime()
					scheduleRawPart = window.scheduleUtils.scheduleRaw.schedule[day]
					sortedKeys = Object.keys(scheduleRawPart).sort (a, b) ->
						a = (new JarvisTimeRange a).startTime
						b = (new JarvisTimeRange b).startTime
						if a < b
							-1
						else if a > b
							1
						else
							0
					for key in sortedKeys
						if (new JarvisTimeRange key).contains time
							classTime = (new JarvisTimeRange key).endTime
							break
					classEnd = classTime - new JarvisTime new Date()
					self.talk "Your class ends in #{classEnd} minutes"
				else
					self.talk "You don't have a class right now"
			class_next:	(self, data) ->
				[day, time] = window.scheduleUtils.getCurrentTime()
				scheduleRawPart = window.scheduleUtils.scheduleRaw.schedule[day]
				sortedKeys = Object.keys(scheduleRawPart).sort (a, b) ->
					a = (new JarvisTimeRange a).startTime
					b = (new JarvisTimeRange b).startTime
					if a < b
						-1
					else if a > b
						1
					else
						0
				if time < (new JarvisTimeRange sortedKeys[0]).startTime
					className = window.scheduleUtils.scheduleRaw.names[scheduleRawPart[sortedKeys[0]]]
				else
					for key, i in sortedKeys
						if (new JarvisTimeRange key).contains time
							if scheduleRawPart[sortedKeys[i+1]] isnt 0
								className = window.scheduleUtils.scheduleRaw.names[scheduleRawPart[sortedKeys[i+1]]]
							else
								className = window.scheduleUtils.scheduleRaw.names[scheduleRawPart[sortedKeys[i+2]]]
							break
				if className?
					self.talk "You have #{className} next"
				else if window.scheduleUtils.getCurrentClass()?
					self.talk "This is your last class of the day"
				else
					self.talk "The day is over!"
			class_now:	(self) ->
				className = window.scheduleUtils.getCurrentClass()
				if className?
					self.talk "You have #{className} right now"
				else
					self.talk "You don't have a class right now"
			class_ordinal:	(self, data) ->
				date = if data.datetime? then new Date data.datetime[0].value.from else new Date()
				day = date.getDay()
				scheduleRawPart = window.scheduleUtils.scheduleRaw.schedule[day]
				sortedKeys = Object.keys(scheduleRawPart).sort (a, b) ->
					a = (new JarvisTimeRange a).startTime
					b = (new JarvisTimeRange b).startTime
					if a < b
						-1
					else if a > b
						1
					else
						0
				.filter (key) ->
						window.scheduleUtils.scheduleRaw.names[scheduleRawPart[key]] in ["Block 1", "Block 2", "Block 3", "Block 4", "Block 5", "Block 6", "Block 7", "Elective A", "Elective B", "Upper School Meeting", "Advisory", "Meetings"]
				if data.ordinal?
					ordinal = data.ordinal?[0].value
				else if data.last?
					sortedKeys.length
				else
					1
				className = window.scheduleUtils.scheduleRaw.names[scheduleRawPart[sortedKeys[ordinal - 1]]]
				
				if className?
					if day is new Date().getDay()
						self.talk "You have #{className} #{getOrdinal ordinal}"
					else
						days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
						self.talk "You have #{className} #{getOrdinal ordinal} on #{days[day]}"
				else
					if day is new Date().getDay()
						self.talk "You only have #{sortedKeys.length} classes today"
					else
						days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
						self.talk "You only have #{sortedKeys.length} classes on #{days[day]}"
			class_time:	(self, data) ->
				date = new Date data.datetime[0].value.from
				day = date.getDay()
				time = new JarvisTime "#{date.getHours()}:#{date.getMinutes()}"
				className = window.scheduleUtils.getClassFromTime window.scheduleUtils.schedule, day, time.toString()
				if className?
					if day is new Date().getDay()
						self.talk "You have #{className} at #{time.toFormattedString()}", phonetic: "You have #{className} at #{time.toSpokenFormattedString()}"
					else
						days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
						self.talk "You have #{className} at #{time.toFormattedString()} on #{days[day]}", phonetic: "You have #{className} at #{time.toSpokenFormattedString()} on #{days[day]}"
				else
					if day is new Date().getDay()
						self.talk "You don't have a class at #{time.toFormattedString()}", phonetic: "You don't have a class at #{time.toSpokenFormattedString()}"
					else
						days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
						self.talk "You don't have a class at #{time.toFormattedString()} on #{days[day]}", phonetic: "You don't have a class at #{time.toSpokenFormattedString()} on #{days[day]}"
			compliment: (self) ->
				self.randpick ["Thank you.", "That's sweet of you.", "You're making me blush.", "You're pretty jamming yourself."]
			creator:	(self) ->
				self.talk "I was created by Yoni Lerner."
			day:		(self) ->
				self.talk "Today is #{moment().format 'dddd, MMMM Do'}"
			directions:	(self, data) ->
				origin = data.origin?[0].value or "My Location"
				destination = data.destination?[0].value
				# if no destination was given, give up
				if not destination?
					self.talk "Please tell me where you want to go."
				else
					$.featherlight(
						$("<iframe></iframe>")
							.attr("src", "https://www.google.com/maps/embed/v1/directions?key=#{apiKeys.googleMaps}&origin=#{encodeURIComponent origin}&destination=#{encodeURIComponent destination}")
							.addClass("lightbox")
					)
					self.talk "Here are the directions you requested"
			hello:		(self) ->
				self.randpick ["Hello", "Hi", "Wazzap ma homie", "Hello sir", "Greetings"]
			help:		(self) ->
				#self.talk "You can say:\n" + (name for name, action of self.actions when name.charAt(0) isnt '_').join "\n"
				self.talk """Please say \"Jarvis\" followed by a request.
You can say:
What class do I have now?
When does this class end?
What's the time?
What is for lunch tomorrow?
When is the next train leaving Hillsdale station?
What day is it?
Who are you?
Who made you?
""", phonetic: "Please say Jarvis followed by a request. You can say all kinds of things. Try it out!"
			insult:		(self) ->
				self.randpick ["I am in beta", "Please be kind, I do my best", "That's not very S E L of you", "What did you just call me"]
			joke:		(self) ->
				self.randpick ["Your programming skills", "My mom wanted me to be a top android, but I'm always at the bot-tom.", "There are 10 types of people: those who know binary and those who don't", "How are calculators like bacteria? They both divide", "How does Bill gates count? 1 2 3 95 98 NT 2000 XP Vista 7 8 10", "What's worse than an apple with a bug in it? A program with a bug in it"]
			leave:		(self) ->
				self.talk "Goodbye sir"
				setTimeout window.clearTerminal, 3000
			location:	(self, data) ->
				location = data.location?[0].value
				if not location?
					self.talk "Please give me a location."
				else
					$.featherlight(
						$("<iframe></iframe>")
							.attr("src", "https://www.google.com/maps/embed/v1/place?key=#{apiKeys.googleMaps}&q=#{encodeURIComponent location}")
							.addClass("lightbox")
					)
			lunch:		(self, data) ->
				nolunch = -> self.talk "There is no lunch service"
				now = moment(data.datetime?[0].value) or moment()
				date = now.format "MM/DD/YY"
				day = now.day()
				
				#Create dish filter
				dishRegex = "of The Day|Farm to Fork"
				if not data?.glutenveggie
					dishRegex += "|Vegetarian|Gluten|Vegan"
				dishRegex = new RegExp dishRegex, "i"
				dishFilter = (dish) -> not dishRegex.test dish
				
				if day is 0 or day is 6
					nolunch()
				else
					$.get("https://www.myschooldining.com/nueva/?cmd=menus&selloc=1294&currDT=#{date}")
						.done((data) ->
							smalldate = now.format "M/D" #format date like the titles
							html = data.results[0]
							menutable = /.*(<table border="0" cellpadding="0">[\s\S]*?<\/table>).*/.exec(html)[0]	#pull out menu table
							menu = $(menutable).find(".calendar-nav:contains(#{smalldate})").parent()				#get relevant day. Insecure, no alternative found
							menu.find(".calendar-nav,br,p:has(a)").remove()											#remove title, line breaks, PDF link
							menu.children().first().remove()														#remove "Lunch"
							window.menu = menu
							if menu.children().first().text() is "No Meal Service"									#check if there is meal service
								nolunch()
							else
								dishes = menu.children('span')														#get all dishes in every category
								dishes = (dish.innerText.replace /» |\s{2,}/g, "" for dish in dishes)				#get dish texts and remove "» "
								dishes = dishes.filter dishFilter													#Filter soup of the day, gluten-free dishes, and veggie sides
								self.talk "The lunch dishes are:\n" + dishes.join "\n"								#say dishes
						).fail ->
							self.actions._disconnected(self)
			month:		(self) ->
				self.talk "The month is #{moment().format 'MMMM'}"
			noreply:	(self) ->
			schedule:	(self, data) ->
				weekday = moment(data.datetime?[0].value).day()
				classes = scheduleUtils.scheduleRaw.schedule[weekday]
				
				self.talk "Here is your schedule", phonetic: "Here is your skejewall"
				table = $("<table></table>")
				for timeRange, classCode of classes
					name = scheduleUtils.scheduleRaw.names[classCode]
					namecell = $("<td></td>").text name
					timecell = $("<td></td>").text timeRange
					row = $("<tr></tr>").append(namecell).append timecell
					table.append row
				$.featherlight table
			search:		(self, data) ->
				if data.search_query?
					engineHash =
						"google": "/proxy/google/search?q="
						"wikipedia": "https://en.wikipedia.org/wiki/Special:Search?search="
						"wolfram alpha": "/proxy/wolfram/?i="
						"bing": "https://www.bing.com/search?q="
						"yahoo": "/proxy/yahoo/search?p="
				
					query = data.search_query[0].value
					engine = data.search_engine?[0].value or "google"
					url = engineHash[engine.toLowerCase()] + encodeURIComponent(query)
					$.featherlight $("<iframe></iframe>").attr("src", url).addClass("lightbox")
				
					self.talk "Searching #{engine} for #{query}"
				else
					self.talk "Please tell me what to search for", phonetic: "Please tell me what to search four"
			smalltalk:	(self) ->
				self.talk "Fine, thanks."
			sorry:		(self) ->
				self.randpick ["It's OK.", "I forgive you.", "You should be ashamed of yourself.", "No problem.", "No worries.", "It's fine.", "Apology accepted."]
			speak:		(self, data) ->
				self.talk data.message_body[0].value
			thanks:		(self) ->
				self.randpick ["You're welcome.", "My pleasure.", "Of course.", "No problem.", "Sure thing.", "Anytime.", "You bet.", "Don't mention it."]
			time:		(self) ->
				now = new Date()
				now = new JarvisTime now
				self.talk "The time is now #{now.toFormattedString()}", phonetic: "The time is now #{now.toSpokenFormattedString()}"
			weather:	(self, data) ->
				$('<div></div>').attr('id', 'weather')
				try
					$.simpleWeather
						location: data.location?[0].value or "San Mateo, CA"
						woeid: ''
						unit: 'f'
						success: (weather) ->
							timestr = data.datetime?[0].value
							time = moment timestr
							location = data.location?[0].value or 'Bay Meadows'
							if timestr isnt null and time.diff(moment(), "days") isnt 0
								forecastNum = time.diff(moment(), "days") + 1
								unless 0 < forecastNum <= 4
									self.talk "I only have a five-day forecast"
									return
								main = """<i class="icon-#{weather.forecast[forecastNum].code}"></i> #{weather.forecast[forecastNum].low}-#{weather.forecast[forecastNum].high}&deg;#{weather.units.temp}"""
								mid = weather.forecast[forecastNum].text
								right = weather.forecast[forecastNum].day
								self.talk "Here is the weather for #{location} on #{time.format 'dddd'}"
							else
								main = """<i class="icon-#{weather.code}"></i> #{weather.temp}&deg;#{weather.units.temp}"""
								mid = weather.currently
								right = "#{weather.humidity}%"
								self.talk "Here is the weather for #{location}"
							$.featherlight $("<div></div>").attr("id", "weather").html """<h2>#{main}</h2>
							<ul><li>#{weather.city}, #{weather.region}</li>
							<li class="currently">#{mid}</li>
							<li>#{right}</li></ul>"""
						error: (error) ->
							$("#weather").html "<p>#{error}</p>"
				catch
					if e.message is "Cannot read property 'channel' of null"
						self.talk "I could not find the weather for #{location}"
					else
						this.failGracefully -> throw e
			whistle:	(self) ->
				numFiles = 3
				file = "/resources/audio/whistle/whistle#{Math.floor(Math.random() * numFiles + 1)}.mp3"
				audio = new Audio file
				audio.play()
			who:		(self) ->
				self.talk "I am Jarvis, a smart personal assistant for Nueva students."
			year:		(self) ->
				self.talk "The year is #{moment().format 'YYYY'}"
			#internal actions
			_unknown:	(self) ->
				self.talk "I didn't understand that.", phonetic: "I did ent understand that"
			_disconnected: (self) ->
				self.talk "I can't connect to the internet"
			_easteregg: (self, egg, callback) ->
				egg = egg.toLowerCase().replace /[^a-z ]/g, ""
				$.get "/eastereggs/#{egg}"
					.done (response) ->
						if response isnt ""
							self.talk response
						else
							callback()
					.fail callback
		failGracefully: (todo) ->
			try
				todo.apply this
			catch error
				console.log "Jarvis error: #{error.stack or error}"
				this.talk "Error. See console for details"
			
	# export jarvis
	(exports ? window).jarvis = jarvis
	
	# greet user
	jarvis.talk "Hello sir"
