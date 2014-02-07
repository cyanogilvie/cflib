# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::config_lite {
	superclass ::cflib::config

	method Interp {} {return {}}
}
