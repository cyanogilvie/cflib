# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create cflib::refcounted {
	constructor {} {
		set keychain	{}
		if {[self next] ne {}} {next}
		set refcount	1
	}

	destructor {
		my _clear_registry
		if {[self next] ne {}} {next}
	}

	variable {*}{
		refcount
		registry_var
		keychain
	}

	method object_registry {varname args} { #<<<
		my _clear_registry

		set registry_var	$varname
		upvar $registry_var var_ref

		set keychain		$args
		if {[llength $keychain] == 0} {
			set var_ref		[self]
		} else {
			dict set var_ref {*}$keychain [self]
		}
	}

	#>>>
	method incref {args} { #<<<
		?? {set old		$refcount}
		incr refcount
		?? {log debug "[self]: refcount $old -> $refcount ($args)"}
	}

	#>>>
	method decref {args} { #<<<
		?? {set old		$refcount}
		incr refcount -1
		?? {log debug "[self]: refcount $old -> $refcount ($args)"}
		if {$refcount <= 0} {
			?? {log debug "[self]: our time has come"}
			my destroy
			return
		}
	}

	#>>>
	method refcount {} { #<<<
		set refcount
	}

	#>>>

	method log_cmd {lvl msg args} {}
	method autoscoperef {} { #<<<
		#my log_cmd debug "[self class]::[self method] callstack: (callstack dump broken)"
		upvar 2 _cflib_refcounted_scoperef_[string map {:: //} [self]] scopevar
		set scopevar	[self]
		trace add variable scopevar {unset} [namespace code {my decref "scopevar unset"}]
	}

	#>>>
	method _clear_registry {} { #<<<
		if {[info exists registry_var]} {
			upvar $registry_var old_registry
			if {[info exists old_registry]} {
				if {[llength $keychain] == 0} {
					unset old_registry
				} else {
					try {
						dict unset old_registry {*}$keychain
					} on error {errmsg options} {
						puts stderr "Could not remove object registry entry: $errmsg"
					}
				}
			}
		}
	}

	#>>>
}


