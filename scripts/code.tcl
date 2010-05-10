# From http://wiki.tcl.tk/21595

namespace eval ::oo::Helpers::cflib {
	proc code {method args} {
		list [uplevel 1 {namespace which my}] $method {*}$args
	}
}
