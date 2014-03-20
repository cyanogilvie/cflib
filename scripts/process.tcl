# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

# Handlers invoked:
#	output(channel, data)	- When output arrives from the child, channel is
#							  one of {stdout, stderr}
#	reaped(result)			- When the child dies and has been reaped.  result
#							  is the numeric result from the child.
#	death_by_signal(childpid, sigal_name, msg)
#							- When a child is killed by a signal.  signame
#							  is something like SIGTERM, msg is something
#							  like "software termination signal"

oo::class create cflib::process {
	uplevel #0 {package require sop}
	superclass sop::signalsource cflib::handlers

	variable {*}{
		cmd
		pids
		res
		handle
		stderr_handle
		buf
		output_matches
		dominos
		signals
		seq
	}

	constructor {args} { #<<<
		set cmd	$args

		array set dominos	{}
		set output_matches	[dict create]
		set pids			{}
		set buf				{}
		set seq				0

		sop::signal new signals(running) -name "[self] running"
		sop::signal new signals(finished) -name "[self] finished"
		sop::domino new dominos(check_output_waits) -name "[self] check_output_waits"

		if {[self next] ne ""} next

		namespace path [concat [namespace path] {
			::oo::Helpers::cflib
		}]

		set stderr_handle	[chan create write [code _stderr_handler]]

		#set cmdline	[list {*}$cmd 2>@ $stderr_handle]
		#set cmdline	[list {*}$cmd >@ $stderr_handle]
		#set cmdline	[list {*}$cmd 2>@ stdout]
		set cmdline	[list {*}$cmd 2>@1]
		#set cmdline	[list {*}$cmd]
		#puts $stderr_handle "hello, world"; flush $stderr_handle
		set handle	[open |$cmdline r]
		chan configure $handle \
				-buffering none \
				-blocking 0 \
				-translation binary \
				-encoding binary
		set pids		[pid $handle]
		chan event $handle readable [code _readable]
		$signals(running) set_state 1

		$dominos(check_output_waits) attach_output [code _check_output_waits]
	}

	#>>>
	destructor { #<<<
		try {
			$signals(running) set_state 0
		} on error {errmsg options} {
			log error [dict get $options -errorinfo]
		}
		if {[info exists handle] && $handle in [chan names]} {
			chan event $handle readable {}
			try {
				chan close $handle
			} on error {errmsg options} {
				log error [dict get $options -errorinfo]
			}
			unset handle
		}
		if {[info exists stderr_handle] && $stderr_handle in [chan names]} {
			try {
				chan close $stderr_handle
			} on error {errmsg options} {
				log error [dict get $options -errorinfo]
			}
			unset stderr_handle
		}

		if {$::tcl_platform(platform) eq "unix"} {
			foreach pid $pids {
				catch {exec kill -15 $pid}
			}
		}

		my _abort_waits

		if {[self next] ne ""} next
	}

	#>>>

	method pids {} {set pids}
	method cmd {} {set cmd}
	method output {} { #<<<
		set build	""
		foreach chunk $buf {
			lassign $chunk channel data
			append build $data
		}
		return $build
	}

	#>>>
	method stdout {} { #<<<
		set build	""
		foreach chunk $buf {
			lassign $chunk channel data
			if {$channel ne "stdout"} continue
			append build $data
		}
		return $build
	}

	#>>>
	method stderr {} { #<<<
		set build	""
		foreach chunk $buf {
			lassign $chunk channel data
			if {$channel ne "stderr"} continue
			append build $data
		}
		return $build
	}

	#>>>
	method result {} { #<<<
		if {![$signals(finished) state]} {
			error "Child yet lives"
		}
		return $res
	}

	#>>>
	method waitfor_output {match {timeout_ms ""}} { #<<<
		if {[string match "*$match*" $buf]} return

		if {[info coroutine] eq ""} {
			error "Can only wait in a coroutine context"
		}
		set waitid	[incr seq]
		dict set output_matches $waitid coro [info coroutine]
		dict set output_matches $waitid match $match
		if {$timeout_ms ne ""} {
			dict set output_matches $waitid afterid [after $timeout_ms \
					[code _wait_timeout $waitid]]
		} else {
			dict set output_matches $waitid afterid ""
		}
		lassign [yield] result options
		return -options $options $result
	}

	#>>>
	method _wait_timeout {waitid} { #<<<
		set coro	[dict get $output_matches $waitid coro]
		set match	[dict get $output_matches $waitid match]
		set options	[dict create]
		dict set options -code error
		dict set options -errorcode [list timeout $match]
		dict unset output_matches $waitid
		after idle [list $coro [list "Timeout waiting for \"$match\"" $options]]
	}

	#>>>
	method _readable {} { #<<<
		set dat	[chan read $handle]
		if {$dat ne ""} {
			lappend buf [list stdout $dat]
		}
		if {[chan eof $handle]} {
			try {
				chan configure $handle -blocking 1
				chan close $handle
			} trap CHILDSTATUS {errmsg options} {
				lassign [dict get $options -errorcode] - childpid res
			} trap CHILDKILLED {errmsg options} {
				lassign [dict get $options -errorcode] - childpid sig msg
				my invoke_handlers death_by_signal $childpid $sig $msg
				set res	""
			} on error {errmsg options} {
				log error "Child died in an interesting way: $errmsg ([dict get $options -errorcode])"
				set res	""
			} on ok {} {
				set res	0
			}
			set pids		{}
			unset handle

			$dominos(check_output_waits) tip
			my invoke_handlers output stdout $dat

			$signals(running) set_state 0
			$signals(finished) set_state 1
			my _abort_waits
			my invoke_handlers reaped $res
			return
		}

		$dominos(check_output_waits) tip

		my invoke_handlers output stdout $dat
	}

	#>>>
	method _stderr_handler {subcmd channelId args} { #<<<
		switch -- $subcmd {
			initialize {
				lassign $args mode
				if {$mode ne "write"} {
					error "Only writing is supported"
				}
				return {
					initialize
					finalize
					watch

					write
					blocking
				}
			}

			finalize {
			}

			watch {
			}

			write {
				lassign $args data
				lappend buf	[list stderr $data]
				my invoke_handlers output stderr $data

				$dominos(check_output_waits) tip

				return [string length $data]
			}

			blocking {
				lassign $args mode
			}

			default {
				error "Unsupported subcommand: ($subcmd)"
			}
		}
	}

	#>>>
	method _check_output_waits {} { #<<<
		set plain	[my output]
		dict for {waitid info} $output_matches {
			set coro	[dict get $info coro]
			set match	[dict get $info match]
			if {[string match "*$match*" $plain]} {
				after cancel [dict get $info afterid]
				dict unset output_matches	$waitid
				after idle [list $coro {"" {-code ok}}]
			}
		}
	}

	#>>>
	method _abort_waits {} { #<<<
		$dominos(check_output_waits) force_if_pending
		dict for {waitid info} $output_matches {
			set coro	[dict get $info coro]
			set match	[dict get $info match]
			after cancel [dict get $info afterid]
			dict unset output_matches	$waitid
			after idle [list $coro [list "child died while waiting for \"$match\"" [list -code error -errorcode [list child_died $match]]]]
		}
	}

	#>>>
}


