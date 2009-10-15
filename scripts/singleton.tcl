# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

# Based on http://rosettacode.org/wiki/Global_Singleton

oo::class create cflib::singleton {
	superclass oo::class

	variable object

	unexport create

	method new {args} { #<<<
		if {![info exists object]} {
			set object	[next {*}$args]
		}
		return $object
	}

	#>>>
}
