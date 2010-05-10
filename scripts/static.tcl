# From http://wiki.tcl.tk/21595

# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::Static {
	method static {args} {
		if {![llength $args]} return

		set callclass	[lindex [self caller] 0]
		define $callclass self export varname
		foreach vname $args {
			lappend pairs	[$callclass varname $vname] $vname
		}
		uplevel 1 upvar {*}$pairs
	}
}

# Use like this:
# oo::class create Foo {
#	mixin cflib::Static
#	variable _inst_num
#
#	constructor {} {
#		my static _max_inst_num
#		set _inst_num	[incr _max_inst_num]
#	}
#
#	method inst {} {
#		return $_inst_num
#	}
#}
