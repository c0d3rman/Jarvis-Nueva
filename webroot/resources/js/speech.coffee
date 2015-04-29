if annyang
	execute = (arg1, arg2) ->
		if arg2? then command = arg2 else command = arg1 #if arg2 is set then arg1 is *garbage
		window.resetInteractionCountdown()
		window.closeLightbox()
		window.jarvis.talk command, speaker: "You"
		window.jarvis.process command
	getPrompted = ->
		window.resetInteractionCountdown()
		window.closeLightbox()
		window.jarvis.talk "Jarvis...", speaker: "You"
		window.jarvis.talk "Yes sir?"
		window.prompted = yes

	commands =
		'jarvis *stuff': execute
		'travis *stuff': execute
		'*garbage jarvis *stuff': execute
		'*garbage travis *stuff': execute
		'jarvis': getPrompted
		'travis': getPrompted
		'*garbage jarvis': getPrompted
		'*garbage travis': getPrompted
		'*stuff': (command) ->
			if window.prompted
				window.prompted = no
				execute command
				
	annyang.addCommands commands
	
	annyang.start()
