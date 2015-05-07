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
		window.jarvis.talk "Yes?"
		window.prompted = yes
	
	commands = {}
	
	names = ['jarvis', 'travis', 'Gervais', 'Java', 'dude']
	for name in names
		commands["#{name} *stuff"] = execute
	for name in names
		commands["*garbage #{name} *stuff"] = execute
	for name in names
		commands["#{name}"] = getPrompted
	for name in names
		commands["*garbage #{name}"] = getPrompted
	# 4 loops for command priority
	
	
	commands['*stuff'] = (command) ->
		if window.prompted
			window.prompted = no
			execute command
	
	annyang.addCommands commands
	
	annyang.start()
