class @JarvisTime
	constructor: (time) ->
		if typeof time is "string"
			throw "Invalid time #{time}" unless time.match /^\d{1,2}:\d{1,2}$/
			[@hours, @minutes] = (Number(t) for t in time.split ":")
			throw "Out of range time #{time}" unless 0 <= @hours < 24 and 0 <= @minutes < 60
		else if typeof time is "number" and time % 1 is 0
			throw "Out of range time #{time}" unless 0 <= time < 1440
			@hours = Math.floor(time / 60)
			@minutes = time % 60
		else if time instanceof JarvisTime
			@hours = time.hours
			@minutes = time.minutes
		else if time instanceof Date
			@hours = time.getHours()
			@minutes = time.getMinutes()
		else
			throw "Unknown input type (#{typeof time}) for input #{time}"
	
	toString: ->
		"#{@hours}:" + (if @minutes < 10 then "0#{@minutes}" else "#{@minutes}")
	toSpokenString: ->
		"#{@hours} #{@minutes}"
	toFormattedString: ->
		string = @hours % 12 or 12
		if 0 < @minutes < 10
			string += ":0#{@minutes}"
		else if 10 <= @minutes <= 60
			string += ":#{@minutes}"
		
		if @hours is @hours % 12
			string += " AM"
		else
			string += " PM"
	toSpokenFormattedString: ->
		string = (@hours % 12 or 12) + " #{@minutes} " + (if @hours is @hours % 12 then "AM" else "PM")
	valueOf: ->
		@hours * 60 + @minutes

class @JarvisTimeRange
	constructor: (@startTime, @endTime) ->
		try
			@startTime = new JarvisTime @startTime
			@endTime = new JarvisTime @endTime
		catch error
			if typeof @startTime is "string" and @startTime.match /^\d{1,2}:\d{1,2}-\d{1,2}:\d{1,2}$/
				[@startTime, @endTime] = (new JarvisTime t for t in @startTime.split "-")
			else
				throw "Invalid input to JarvisTimeRange constructor (#{@startTime}, #{@endTime})"
		
		unless @endTime - @startTime >= 0
			throw "Start time (#{@startTime.toString()}) after end time (#{@endTime.toString()})"
	
	toString: ->
		"#{@startTime.toString()}-#{@endTime.toString()}"
	
	length: ->
		@endTime - @startTime
	
	contains: (time) ->
		@startTime <= time < @endTime

window.scheduleUtils =
	minuteByMinute: (timeRange) ->
		unless timeRange.match /^\d{1,2}:\d{2}-\d{1,2}:\d{2}$/
			throw Error "Bad input to minuteByMinute: #{timeRange}"
	
		[startTime, endTime] = (new JarvisTime(time) for time in timeRange.split "-")
		unless startTime < endTime
			throw Error "Start time after end time in minuteByMinute: #{timeRange}"
	
		output = []
		for time in [startTime + 0..endTime - 1]
			time = new JarvisTime time
			output.push time.toString()
		output
	
	parseSchedule: (data) ->
		output = []
		classes = data.names
		for day in data.schedule
			today = {}
			for timeRange, classCode of day
				for time in this.minuteByMinute timeRange
					today[time] = classes[classCode]
			output.push today
		output
	
	scheduleRaw: null

	getClassFromTime: (schedule, day, time) ->
		schedule[day][time]

	getCurrentTime: ->
		now = moment()
		return [now.day(), new JarvisTime now.format "HH:mm"]
	
	getCurrentClass: ->
		this.getClassFromTime this.schedule, this.getCurrentTime()...

jQuery.ajax
	url: '/resources/data/blockSchedule.json'
	dataType: "json"
.done (json) ->
	window.scheduleUtils.scheduleRaw = json
	window.scheduleUtils.schedule = window.scheduleUtils.parseSchedule window.scheduleUtils.scheduleRaw
