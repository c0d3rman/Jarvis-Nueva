doctype 5
html ->
	head ->
		title 'Jarvis'

		meta 'http-equiv': 'Content-Type', content: 'text/html; charset=UTF-8'
		meta name: 'description', content: 'A digital personal assistant for Nueva students that accepts voice commands.'
		meta name: 'keywords', content: 'jarvis,personal assistant,assistant,voice command,jarvis personal assistant,Nueva,The Nueva School'
		meta property: 'og:title', content: 'Jarvis Personal Assistant'
		meta property: 'og:type', content: 'website'
		meta property: 'og:site_name', content: 'Jarvis Personal Assistant'
		meta property: 'og:description', content: "Jarvis is a digital personal assistant for Nueva students that accepts voice commands. He can play music, calculate mathematical expressions, tell you what's for lunch, search, and more!"
		meta property: 'og:url', content: 'https://jarvispa.info/'

		link href: '/resources/lib/font-awesome.min.css', rel: 'stylesheet'
		link href: '/resources/lib/featherlight.min.css', rel: 'stylesheet'
		link href: '/resources/css/main.css', rel: 'stylesheet'
		link href: '/resources/css/weather.css', rel: 'stylesheet'
		link href: '/resources/images/favicon.png', rel: 'icon', type: 'image/png'
		
		script src: '/resources/lib/jquery.min.js'
		script src: '/resources/lib/annyang.js'
		script src: '/resources/lib/profanity.js'
		script src: '/resources/lib/moment.min.js'
		script src: '/resources/lib/jquery.xdomainajax.js'
		script src: '/resources/lib/mixpanel.js'
		script src: '/resources/lib/featherlight.min.js'
		script src: '/resources/lib/jquery.simpleWeather.min.js'
		script src: '/resources/lib/jquery.ajax-retry.min.js'
		script src: '/resources/lib/speakjs/speakClient.js'

		script src: '/resources/js/util.js'
		script src: '/resources/js/apikeys.js'
		script src: '/resources/js/jarvis.js'
		script src: '/resources/js/script.js'
		script src: '/resources/js/speech.js'
		script src: '/resources/js/schedule.js'
	
	body ->
		div '#headerDiv.resp', ->
			a '#header', href: './', 'JARVIS'
		h1 '#tagline.resp', ->
			span '.fa.fa-angle-right', @empty
			text " Nueva's smart personal assistant"
			
		div '#content', ->
			p '#directions', 'Please type in your request or ask for help'
			div '#terminal', ->
				p '#terminalContent', @empty
				span '#inWrapper', ->
					text 'You: '
					input '#in', name: 'in', type: 'text'
		
		audio '#myPlayer', @empty
		div '#audio', @empty
		
		footer '.resp', ->
			text '&copy; 2014 '
			a '.fancyLink', href: 'https://jarvispa.info/', target: '_blank', 'Yoni'
			text '.'
