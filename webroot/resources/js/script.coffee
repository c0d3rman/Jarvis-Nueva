$(document).ready ->
	#---------------------------
	#	Adaptive Directions
	#---------------------------
	setInterval ->
		navigator.webkitGetUserMedia {video: false, audio: true}, ->
			$("#directions").text 'Please say "Jarvis" followed by your request or ask for help'
		, (e) ->
			console.log e
	
	
	#---------------------------
	#	Terminal Customization
	#--------------------------- 
	# add a method to submit the terminal
	submitTerminal = ->
		if $("#in").val() isnt ""
			window.jarvis.talk $("#in").val(), speaker: "You"
			window.jarvis.process $("#in").val()
			$("#in").val("")
	
	window.submitTerminal = submitTerminal
	
	# submit on enter anywhere in page (and save entries)
	$(document).keydown (event) ->
		resetInteractionCountdown()
		if event.keyCode == 13
			window.submitTerminal()
		else if event.keyCode == 27
			annyang.stop()
	
	# keep #in focused
	$("#in").focus()
	$("#in").blur ->
		$(this).focus()
	
	window.interactionCountdown = 0
	
	# provide method to clear terminal
	window.clearTerminal = -> $("#terminalContent").children().fadeOut -> $(this).remove()
	
	# provide method to close lightbox if it is open
	window.closeLightbox = -> $.featherlight.current()?.close()
	
	# clear terminal after no interaction for 15 seconds
	setInterval ->
		if window.interactionCountdown is 0
			window.clearTerminal()
			window.closeLightbox()
			window.interactionCountdown = -1 # don't keep clearing terminal
		else if window.interactionCountdown > 0
			window.interactionCountdown--
	, 1000
	
	# provide method to reset countdown
	window.resetInteractionCountdown = -> window.interactionCountdown = 15
	
	# set starting interaction countdown
	resetInteractionCountdown()
