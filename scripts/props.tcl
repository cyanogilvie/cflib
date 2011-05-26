# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::props {
	method _properties {} {return {}}

	constructor args {
		if {[self next] ne ""} next

		my _init_props $args
	}

	method _init_props {argv} {
		my variable _propbase_initialized
		if {![info exists _propbase_initialized]} {
			cflib::config_lite create prop $argv [my _properties]

			set _propbase_initialized	1
		}
	}

	forward configure	prop configure
	forward cget		prop cget
}
