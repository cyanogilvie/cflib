# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> foldmarker=<<<,>>>

oo::class create cflib::baselog {
	method log {lvl {msg ""} args} {
		puts "$msg"
		#uplevel [string map [list %lvl% $lvl %msg% $msg %args% $args] {
		#	puts "[self] [self class]::[self method] %lvl% %msg%"
		#}]
	}
}


