#from http://stackoverflow.com/questions/8897289/how-to-check-if-an-element-is-off-screen
jQuery.expr.filters.offscreen = (el) ->
	(el.offsetLeft + el.offsetWidth) < 0 or (el.offsetTop + el.offsetHeight) < 0 or (el.offsetLeft > window.innerWidth or el.offsetTop > window.innerHeight)
	
#shuffle function from https://gist.github.com/ddgromit/859699
window.shuffle = (a) ->
	i = a.length
	while --i > 0
		j = ~~(Math.random() * (i + 1))
		t = a[j]
		a[j] = a[i]
		a[i] = t
	a

#from https://ecommerce.shopify.com/c/ecommerce-design/t/ordinal-number-in-javascript-1st-2nd-3rd-4th-29259
window.getOrdinal = (n) ->
	s = ["th", "st", "nd", "rd"]
	v = n % 100
	n + (s[(v - 20) % 10] || s[v] || s[0])