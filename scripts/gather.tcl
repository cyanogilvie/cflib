# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> foldmarker=<<<,>>>

package require gc_class
package require parse_args
package require sop

namespace eval ::cflib {
	proc gather_results_cb {obj name result} { #<<<
		if {![info object isa object $obj]} return	;# Can happen when a timed out result eventually arrives and the gather instance is gone
		$obj slot_ready $name $result
	}

	#>>>
}

gc_class create cflib::gather {
	superclass ::sop::signalsource

	variable {*}{
		timeout_afterid
		signals
		results
		processors
	}

	constructor args { #<<<
		namespace path [list {*}{
			::parse_args
		} {*}[namespace path]]

		parse_args $args {
		}

		set timeout_afterid	""
		set results			{}
		set processors		{}
		array set signals	{}
		sop::gate new signals(ready) -mode and -name "ready" -default true

		if {[self next] ne ""} next
	}

	#>>>
	destructor { #<<<
		after cancel $timeout_afterid; set timeout_afterid	""
		if {[self next] ne ""} next
	}

	#>>>
	method slot {name args} { #<<<
		parse_args $args {
			-process	{-default {}}
		}

		if {[info exists signals(slot_$name)]} {
			error "slot $name already allocated"
		}

		sop::signal new signals(slot_$name) -name "slot $name ready"
		$signals(ready) attach_input $signals(slot_$name)
		dict set processors $name $process

		list ::cflib::gather_results_cb [self] $name
	}

	#>>>
	method slot_ready {name result} { #<<<
		if {![info exists signals(slot_$name)]} {
			error "Recieved result for non-existant slot \"$name\""
		}

		if {[dict get $processors $name] ne {}} {
			set result	[{*}[dict get $processors $name] $result]
		}
		dict set results $name $result
		$signals(slot_$name) set_state 1
	}

	#>>>
	method results args { #<<<
		parse_args $args {
			-timeout	{-# {If set, wait up to this many seconds for all results to be ready}}
			-partial	{-boolean -# {If set, return whatever results are ready without waiting}}
		}

		if {!$partial} {
			if {[info exists timeout]} {
				$signals(ready) waitfor true [expr {int($timeout * 1000)}]
			} else {
				$signals(ready) waitfor true
			}
		}

		set results
	}

	#>>>
	method slots args { #<<<
		parse_args $args {
			state	{-enum {all ready waiting} -default all}
		}

		switch -exact -- $state {
			all {
				list \
					ready	[my slots ready] \
					waiting	[my slots waiting]
			}

			ready {
				lsort -dictionary [lmap {name sig} [array get signals] {
					if {![string match slot_* $name] || ![$sig state]} continue
					string range $name 5 end
				}]
			}

			waiting {
				lsort -dictionary [lmap {name sig} [array get signals] {
					if {![string match slot_* $name] || [$sig state]} continue
					string range $name 5 end
				}]
			}

			default {
				error "Invalid state requested: \"$state\""
			}
		}
	}

	#>>>
}
