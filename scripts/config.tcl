# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::config {
	variable {*}{
		definitions
		cfg
		rest
	}

	constructor {argv config {configfile ""}} { #<<<
		if {[self next] ne ""} next

		package require dsl 0.4
		set cfg	[dict create]

		#set slave	[interp create -safe]
		set slave	[my Interp]
		try {
			dsl::dsl_eval $slave {
				variable {definitionsvar varname default} { #<<<
					dict set $definitionsvar $varname default $default
				}

				#>>>
				file {definitionsvar op args} { #<<<
					switch -- $op {
						normalize -
						exists -
						readable -
						type -
						dirname -
						rootname -
						extension -
						tail -
						join {
							tailcall file $op {*}$args
						}

						default {
							error "Method \"$op\" of file is not allowed"
						}
					}
				}

				#>>>
			} $config [namespace which -variable definitions]
		} finally {
			if {$slave ne {} && [interp exists $slave]} {
				interp delete $slave
			}
		}

		if {$configfile ne "" && [file readable $configfile]} {
			set cfg	[dict merge $cfg [dsl::decomment [cflib::readfile $configfile]]]
		}

		set rest	[my configure {*}$argv]
	}

	#>>>
	method Interp {} {interp create -safe}
	method configure {args} { #<<<
		set thisrest	{}

		set mode	"key"
		foreach arg $args {
			if {$arg eq "--"} {
				set mode	"forced_rest"
				continue
			}
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
						lappend thisrest	$arg
					}
				}

				val {
					dict set cfg $key $arg
					set mode	"key"
				}

				forced_rest {
					lappend thisrest	$arg
				}
			}
		}

		dict for {k v} $definitions {
			if {![dict exists $cfg $k]} {
				dict set cfg $k [dict get $definitions $k default]
			}
		}

		set thisrest
	}

	#>>>
	method cget {param} { #<<<
		if {[string index $param 0] ne "-"} {error "Syntax error"}
		my get [string range $param 1 end]
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
	method set {key newval} { #<<<
		dict set cfg $key $newval
	}

	#>>>
	method rest {} { #<<<
		return $rest
	}

	#>>>
	method unknown {cmd args} { #<<<
		if {[string index $cmd 0] eq "@"} {
			switch -exact -- [llength $args] {
				0 {dict get $cfg [string range $cmd 1 end]}
				1 {dict set $cfg [string range $cmd 1 end] [lindex $args 0]}
				default {return -code error -level 2 "Wrong number of args, should be [self] $cmd ?newvalue?"}
			}
		} else {
			next $cmd {*}$args
		}
	}

	#>>>
}
