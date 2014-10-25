if annyang
	execute = (command) ->
		window.jarvis.talk command, speaker: "You"
		window.jarvis.process command
	getPrompted = ->
		window.jarvis.talk "Jarvis...", speaker: "You"
		window.jarvis.talk "Yes sir?"
		window.prompted = yes

	commands =
		'jarvis *stuff': execute
		'travis *stuff': execute
		'jarvis': getPrompted
		'travis': getPrompted
		'*stuff': (command) ->
			if window.prompted
				window.prompted = no
				execute command
				
	annyang.addCommands commands
	
	annyang.start()
