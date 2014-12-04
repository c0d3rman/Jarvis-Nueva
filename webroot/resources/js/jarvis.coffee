$(document).ready ->
	# define jarvis object for others to interact with
	jarvis =
		player: $("#myPlayer").get(0)
		swearWords: ( ->
			tempObj = null
			jQuery.ajax url: '/resources/data/swearWords.json', async: no, dataType: "json", success: (json) ->
				tempObj = json
			tempObj
		)()
		# add a talk fuction to submit messages to terminal
		talk: (message, {speaker, phonetic} = {}) ->
			this.failGracefully ->
				speaker ?= "Jarvis" 						# speaker default is "Jarvis"
				message = message
					.replace(/<(?:.|\n)*?>/gm, '')			# remove HTML
					.replace /[^A-Z0-9!.?:;,\s'"-]/ig, ''	# zap gremlins'
				phonetic ?= message 			# phonetic default is the message
			
				phonetic = phonetic.split /\n/	# make new lines into their own utterances
				
				uid = Math.floor(Math.random() * 100000)
				$("#terminalContent").append $("<p></p>").text(speaker + ': ' + message).attr 'id', uid
				setTimeout (id) ->
					$("#" + id).fadeOut 1000, -> $(this).remove()
				, 5000, uid
				$(document).profanityFilter customSwears: this.swearWords
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
						speak phonetic.join("\n"), {pitch: 20}
		# handle utterance queueing
		queue: []
		queueUp: (message) ->
			this.queue.push message
			if this.queue.length is 1
				speechSynthesis.cancel()
				speechSynthesis.speak message
		
		process: (command) ->
			this.failGracefully ->
				$.ajax({
					url: "https://api.wit.ai/message"
					data:
						'v': '20141001' #Oct 1st 2014
						'q': command
						'access_token': "HFJ5Y3XFVSEXQICMCUPICOJKO6IIBECQ"
					dataType: "jsonp"
					jsonp: "callback"
					method: "POST"
					timeout: 1000
				}).done((data) ->
					confidence = data.outcomes[0].confidence
					if confidence > 0.6
						window.jarvis.understand data
					else
						window.jarvis.actions._unknown(window.jarvis)
				).fail((jqXHR, textStatus, errorThrown) ->
					console.log 'textStatus: ' + textStatus
					console.log 'errorThrown: ' + errorThrown
					console.log 'jqXHR: ' + jqXHR
					if not navigator.onLine
						window.jarvis.talk "I can't connect to the internet", phonetic: "I cant connect to the internet"
						throw errorThrown
					else if textStatus is 'timeout'
						@tryCount++
						if @tryCount <= 3
							$.ajax @
						else
							mixpanel.track "timeout"
							window.jarvis.talk "I'm having trouble connecting with my servers", phonetic: "I am having trouble connecting with my servers"
					else
						window.jarvis.failGracefully ->
							throw errorThrown
				)
				
		understand: (rawData) ->
			this.failGracefully ->
				intent = rawData.outcomes[0].intent
				data = rawData.outcomes[0].entities
				mixpanel.track intent
				(this.actions[intent] or this.actions._unknown)(this, data)
		
		actions:
			hello:		(self) ->
				greetings = ["Hello", "Hi", "Wazzap ma homie", "Hello sir", "Greetings"]
				self.talk greetings[Math.floor(Math.random() * greetings.length)]
			list:		(self, data) ->
				$.get("/resources/userMusic/", (data) ->
					data = (data[i] = element.slice(0, -4).replace /_/g, " " for element, i in data.split "\n").slice 0, -1
					self.talk "I can play:\n#{data.join "\n"}"
				).fail ->
					self.talk "Connect to the internet to play music"
					
			pause:		(self, data) ->
				self.player.pause()
				self.talk "Pausing song"
			play:		(self, data) ->
				songName = data.song_name[0].value
				filename = songName.replace(new RegExp(' ', 'g'), "_").toLowerCase() + ".mp3" #uses RegExp object to avoid leading whitespace regex division bug (#607 in GitHub)
				filepath = "/resources/userMusic/#{filename}"
				$.get(filepath)
					.done( ->
						$(self.player).attr "src", filepath
						self.player.play()
						self.talk "Playing #{songName}"
					).fail ->
						self.player.pause()
						self.talk "I don't have the song #{songName}"
			speak:		(self, data) ->
				self.talk data.message_body[0].value
			shuffle:	(self) ->
					$.get("/resources/userMusic/", (data) ->
						data = (data[i] = element.slice(0, -4).replace /_/g, " " for element, i in data.split "\n").slice 0, -1
						
						#shuffle function from https://gist.github.com/ddgromit/859699
						shuffle = (a) ->
							i = a.length
							while --i > 0
								j = ~~(Math.random() * (i + 1))
								t = a[j]
								a[j] = a[i]
								a[i] = t
							a
						data = shuffle data
						self.actions.play self, {song_name: [{value: data[0]}]}
					).fail ->
						self.talk "Connect to the internet to play music"
			search:		(self, data) ->
				engineHash =
					"google": "https://www.google.com/search?q="
					"wikipedia": "http://en.wikipedia.org/wiki/Special:Search?search="
					"wolfram alpha": "http://www.wolframalpha.com/input/?i="
				
				query = data.search_query || data.wikipedia_search_query || data.wolfram_search_query
				query = query[0].value
				engine = data.search_engine?.value || "google"
				window.open engineHash[engine.toLowerCase()] + encodeURIComponent(query), "_self"
				
				self.talk "Searching #{engine} for #{query}"
			unpause:	(self, data) ->
				self.player.play()
				self.talk "Unpausing song"
			calculate:	(self, data) ->
				expression = data.math_expression[0].value
				self.talk "Calculating #{expression}"
				window.open "http://www.wolframalpha.com/input/?i=#{encodeURIComponent expression}", "_self"
			help:		(self) ->
				#self.talk "You can say:\n" + (name for name, action of self.actions when name.charAt(0) isnt '_').join "\n"
				self.talk """You can say:
What class do I have now?
What's the time?
What is for lunch tomorrow?
What day is it?
Who are you?
Who made you?
When does this class end?
"""
			class_now:	(self) ->
				#className = window.scheduleUtils.getClassFromTime window.scheduleUtils.schedule, data.datetime[0].value.from
				className = window.scheduleUtils.getCurrentClass()
				if className?
					self.talk "You have #{className} right now"
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
				getOrdinal = (n) -> #from https://ecommerce.shopify.com/c/ecommerce-design/t/ordinal-number-in-javascript-1st-2nd-3rd-4th-29259
					s = ["th", "st", "nd", "rd"]
					v = n % 100
					n + (s[(v - 20) % 10] || s[v] || s[0])
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
			time:		(self) ->
				now = new Date()
				now = new JarvisTime now
				self.talk "The time is now #{now.toFormattedString()}", phonetic: "The time is now #{now.toSpokenFormattedString()}"
			day:		(self) ->
				now = moment()
				self.talk "Today is #{now.format 'dddd, MMMM Do'}"
			who:		(self) ->
				self.talk "I am Jarvis, a smart personal assistant for Nueva students."
			creator:	(self) ->
				self.talk "I was created by Yoni Lerner."
			lunch:		(self, data) ->
				nolunch = -> self.talk "There is no lunch service"
				now = moment(data?.datetime[0].value.from) or moment()
				date = now.format "MM/DD/YY"
				day = now.day()
				
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
								dishes = (dish.innerText.replace "» ", "" for dish in dishes)						#get dish texts and remove "» "
								dishes = dishes.filter (dish) -> not dish.match /of The Day|Gluten|Farm to Fork/i	#Filter soup of the day, gluten-free dishes, and veggie sides
								self.talk "The lunch dishes are:\n" + dishes.join "\n"								#say dishes
						).fail ->
							self.actions._disconnected(self)
			insult:		(self) ->
				responses = ["I am in beta", "Please be kind, I do my best", "That's not very S E L of you"]
				self.talk responses[Math.floor(Math.random() * responses.length)]
			#internal actions
			_unknown:	(self) ->
				self.talk "I didn't understand that.", phonetic: "I did ent understand that"
			_disconnected: (self) ->
				self.talk "I can't connect to the internet"
		failGracefully: (todo) ->
			try
				todo.apply this
			catch error
				this.talk "Error. See console for details"
				console.log "Jarvis error: #{error.stack or error}"
			
	# export jarvis
	(exports ? window).jarvis = jarvis
	
	# greet user
	jarvis.talk "Hello sir"
