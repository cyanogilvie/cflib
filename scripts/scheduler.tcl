# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

# Expected Datasource schema:
#	column 0:	ID
#	column 1:	event_source_script

# event_source_script must define a proc get_events {start_s end_s}
# that returns a list of event descriptions, each a list of
# {epoc_seconds event_data}
# Example (generates hourly events on the hour):
#
# proc get_events {start_s end_s} {
#	set events	{}
#	set s	[expr {($start_s / 3600) * 3600}]
#	while {$s < $end_s} {
#		lappend events	[list $s [list the_posted_event_for $s]]
#		incr s 3600
#	}	
#	return $events
# }

# Handers fired:
#	event_fired(script_id, event_data)	- When a scheduled event fires

cflib::pclass create cflib::scheduler {
	superclass cflib::baselog cflib::handlers

	property events_ds		""
	property script_col		1
	property window_days	1.0
	property last_run_fn	""

	variable {*}{
		posted
		afterids
		refresh_afterid
		current_horizon
	}

	constructor {args} { #<<<
		set refresh_afterid		""

		set posted		[dict create]
		set afterids	[dict create]

		my configure {*}$args

		foreach reqf {events_ds} {
			if {![info exists $reqf] || [set $reqf] == ""} {
				error "Must set -$reqf"
			}
		}

		if {
			![info object isa object $events_ds] ||
			![info object isa typeof $events_ds ds::datasource]
		} {
			error "-events_ds must be a ds::datasource or descendant"
		}

		if {
			[info object isa typeof $events_ds ds::dschan] ||
			[info object isa typeof $events_ds ds::datasource_filter]
		} {
			$events_ds register_handler new_item	[my code _new_item]
			$events_ds register_handler change_item	[my code _change_item]
			$events_ds register_handler remove_item	[my code _remove_item]
			my _setup_events
		} else {
			$events_ds register_handler onchange	[my code _refresh]
			my _setup_events
		}
	}

	#>>>
	destructor { #<<<
		after cancel $refresh_afterid; set refresh_afterid	""

		dict for {s afterid} $afterids {
			after cancel $afterid
			dict unset afterids $s
		}

		if {
			[info exists events_ds] &&
			[info object isa object $events_ds] &&
			(
				[info object isa typeof $events_ds ds::dschan] ||
				[info object isa typeof $events_ds ds::datasource_filter]
			)
		} {
			$events_ds deregister_handler new_item		[my code _new_item]
			$events_ds deregister_handler change_item	[my code _change_item]
			$events_ds deregister_handler remove_item	[my code _remove_item]
			$events_ds deregister_handler init			[my code _setup_events]
		}
	}

	#>>>

	# Test framework helpers
	method _test_pending_events {} { #<<<
		set build	{}
		foreach s [lsort -integer -increasing [dict keys $posted]] {
			lappend build	$s [dict get $posted $s]
		}
		return $build
	}

	export _test_pending_events
	#>>>

	method _fire {s} { #<<<
		set afterinfo	{}
		foreach id [after info] {
			lappend afterinfo	[list $id [after info $id]]
		}
		#my log debug "\nposted for this slot: [llength [dict get $posted $s]] items: ([join [dict get $posted $s] |])\npending afters:\n\t[join $afterinfo \n\t]"
		if {[dict exists $afterids $s]} {
			after cancel [dict get $afterids $s]
			dict unset afterids $s
		}
		if {![dict exists $posted $s]} return

		foreach event [dict get $posted $s] {
			try {
				my _process_event $event
			} on error {errmsg options} {
				my log error "error processing event: $errmsg\n[dict get $options -errorinfo]"
			}
		}
		dict unset posted $s

		my _update_last_run $s
	}

	#>>>
	method _process_script {id script start_s end_s} { #<<<
		set interp	[interp create -safe]

		$interp alias remove_ev_source [my code _remove_ev_source $id]

		try {
			$interp eval $script
			if {[$interp eval {expr {
				[info commands get_events] eq "get_events"
			}}]} {
				set events	[$interp eval [list get_events $start_s $end_s]]
			} else {
				set events	{}
				my log error "Event source $id does not define get_events proc"
			}
		} on error {errmsg options} {
			my log error "Error initializing safe interpreter with script or calling get_events: $errmsg ([dict get $options -errorcode])\n[dict get $options -errorinfo]"
		} on ok {} {
			foreach event $events {
				lassign $event s event_data

				if {$s < $start_s || $s > $end_s} continue

				dict lappend posted $s	[list $id $event_data]
				if {![dict exists $afterids $s]} {
					set delta	[expr {$s - [my _now]}]
					if {$delta < 1} {
						set delta	1
					}
					#my log debug "scheduling after for $delta seconds time (slot $s)"
					dict set afterids $s	[after [expr {$delta * 1000}] \
							[my code _fire $s]]
				}
			}
		}

		interp delete $interp
	}

	#>>>
	method _process_event {event} { #<<<
		lassign $event script_id event_data
		my invoke_handlers event_fired $script_id $event_data
	}

	#>>>
	method _setup_events {} { #<<<
		after cancel $refresh_afterid; set refresh_afterid	""

		set last_run	[my _get_last_run]

		set end_s	[expr {[my _now] + int($window_days * 86400)}]
		set current_horizon	$end_s
		
		set id_column	[$events_ds cget -id_column]
		foreach row [$events_ds get_list {}] {
			set script_id	[lindex $row $id_column]
			my _new_item foo $script_id $row
		}

		set delta	[expr {($end_s - [my _now]) * 1000}]

		set refresh_afterid	[after $delta [my code _refresh]]
	}

	#>>>
	method _remove_ev_source {id} { #<<<
		set now				[my _now]

		dict for {s event} $posted {
			set new_events	{}
			foreach event $events {
				set ev_script_id	[lindex $event 2]
				if {$ev_script_id ne $id} {
					lappend new_events $event
				}
			}

			if {[llength $new_events] != [llength $events]} {
				if {[llength $new_events] == 0} {
					if {$s >= $now} {
						after cancel $afterid
						dict unset afterids $s
						dict unset posted $s
					}
				} else {
					dict set posted $s	$new_events
				}
			}
		}
	}

	#>>>
	method _update_last_run {{s now}} { #<<<
		if {$last_run_fn eq ""} return

		if {$s eq "now"} {
			set s	[my _now]
		}

		set fp	[open $last_run_fn w]
		try {
			chan puts $fp $s
		} finally {
			chan close $fp
		}
	}

	#>>>
	method _refresh {} { #<<<
		set now		[my _now]
		my _update_last_run $now

		dict for {s afterid} $afterids {
			if {$s >= $now} {
				after cancel $afterid
				dict unset afterids $s
				dict unset posted $s
			}
		}
		my _setup_events
	}

	#>>>
	method _get_last_run {} { #<<<
		if {$last_run_fn eq ""} {
			return [my _now]
		}

		try {
			set fp	[open $last_run_fn r]
		} on error {errmsg options} {
			set last_run	""
		} on ok {} {
			set last_run	[chan read $fp]
			chan close $fp
		}

		if {![string is integer -strict $last_run]} {
			set last_run	[my _now]
		}

		return $last_run
	}

	#>>>
	method _now {} { #<<<
		clock seconds
	}

	#>>>

	method _new_item {pool id data} { #<<<
		set script	[lindex $data $script_col]
		my _new_source $id $script
	}

	#>>>
	method _change_item {pool id olddata newdata} { #<<<
		set oldscript	[lindex $olddata 1]
		set newscript	[lindex $newdata 1]
		if {$oldscript eq $newscript} return
		my _remove_ev_source $id
		my _new_item $pool $id $newdata
	}

	#>>>
	method _remove_item {pool id olddata} { #<<<
		my _remove_ev_source $id
	}

	#>>>
	method _new_source {id script} { #<<<
		if {![info exists current_horizon]} {
			error "current_horizon not defined"
		}
		set start_s	[my _now]
		set end_s	$current_horizon

		my _process_script $id $script $start_s $end_s
	}

	#>>>
}


