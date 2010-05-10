# From http://wiki.tcl.tk/21595

namespace eval ::oo::Helpers::cflib {
	proc classvar {name args} {
		set ns	[info object namespace [uplevel 1 {self class}]]
		set vs	[list $name $name]
		foreach v $args {
			lappend vs $v $v
		}
		tailcall namespace upvar $ns {*}$vs
	}
}

# Use like this:
#oo::class create Foo {
#	method bar {z} {
#		cflib::classvar x y
#		return [incr x $z],[incr y]
#	}
#}
#
# or:
#
#oo::class create Foo {
#	constructor {} {
#		namespace path [concat [namespace path] {::oo::Helpers::cflib}]
#	}
#	method bar {z} {
#		classvar x y
#		return [incr x $z],[incr y]
#	}
#}
