# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::config {
	variable {*}{
		definitions
		cfg
		rest
	}

	constructor {argv config} { #<<<
		package require dsl
		set cfg	[dict create]

		set slave	[interp create -safe]
		try {
			dsl::dsl_eval $slave {
				variable {definitionsvar varname default} { #<<<
					dict set $definitionsvar $varname default $default
				}

				#>>>
			} $config [namespace which -variable definitions]
		} finally {
			if {[interp exists $slave]} {
				interp delete $slave
			}
		}

		set mode	"key"
		set rest	{}
		foreach arg $argv {
			switch -- $mode {
				key {
					if {[string index $arg 0] eq "-"} {
						set key	[string range $arg 1 end]
						if {![dict exists $definitions $key]} {
							throw [list bad_config_setting $key] \
									"Invalid config setting: \"$key\""
						}
						set mode	"val"
					} else {
						lappend rest	$arg
					}
				}

				val {
					dict set cfg $key $arg
					set mode	"key"
				}
			}
		}

		dict for {k v} $definitions {
			if {![dict exists $cfg $k]} {
				dict set cfg $k [dict get $definitions $k default]
			}
		}
	}

	#>>>
	method get {key args} { #<<<
		switch -- [llength $args] {
			0 {
				if {![dict exists $cfg $key]} {
					throw [list bad_config_setting $key] \
							"Invalid config setting: \"$key\""
				}
				return [dict get $cfg $key]
			}

			1 {
				if {[dict exists $cfg $key]} {
					return [dict get $cfg $key]
				} else {
					return [lindex $args 0]
				}
			}

			default {
				error "Too many arguments: expecting key ?default?"
			}
		}
	}

	#>>>
	method rest {} { #<<<
		return $rest
	}

	#>>>
}
