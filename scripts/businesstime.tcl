# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

# These routines should be DST (daylight savings time) compatible for dates
# later than 2007

# -office_hours format =========================================================
# In BNF like language: (foo{n..m} means a Tcl list with [n,m] elements)
# office_hours:		timespec{0..n}
# timespec:			range SP times
# SP:				\s+
# range:			dow | (dow "-" dow)
# dow:				"Monday" | "Tuesday" | "Wednesday" | "Thursday" | "Friday" | "Saturday" | "Sunday"	# or any case-insensitive unique prefix of at least 3 characters
# times:			time_range{0..n}
# time_range:		time SP time
# time:				(tval meridian) | tval
# tval:				hours | (hours ":" minutes) | (hours ":" minutes ":" seconds)
# meridian:			"am" | "AM" | "pm" | "PM"
# hours:			0 - 24		# or 0 - 12 if used with a meridian
# minutes:			0 - 59
# seconds:			0 - 59
#
# Some examples:
#	"Thu {10:30am 4pm}"		- Only open on Thursdays from 10:30am till 4pm
#	""						- Never open
#	"Monday-Sun {00:00 24:00}"
#							- Open 24/7
#	"Wed {9am 5pm} Mon-Fri {8am 5pm} Sat {8:30am 11:30am}"
#							- Open from 8am to 5pm on weekdays, except for Wednesday which is 8am to 5pm, and Saturday from 8:30am till 11:30am
#	"Mon-Fri {8am 5pm} Wed {9am 5pm} Sat {8:30am 11:30am}"
#							- Open from 8am to 5pm on weekdays, and Saturday from 8:30am till 11:30am.  Note that the first matching range is used, so in this case the special hours for Wednesday are ignored

# -special_days ================================================================
# special_days specifies a callback that is passed a day (given as seconds from
# the unix epoch), and must return a value in one of the following forms:
#	"normal"/<false>			- to signal normal rules from
#									office_hours apply
#	"holiday"/<true>			- to signal a holiday, ie. no work hours
#	?start_time end_time?...	- a list of 0..n pairs of times, like the times
#									portion of the office_hours setting

oo::class create cflib::businesstime {
	variable {*}{
		dow_range_cache
		office_hours_compiled
		step_mode
	}

	constructor {args} { #<<<
		if {[self next] ne ""} next

		set dow_range_cache	{}

		if {"::tcl::mathop" ni [namespace path]} {
			namespace path [concat [namespace path] {
				::tcl::mathop
			}]
		}

		cflib::config_lite create cfg $args {
			variable office_hours	{Mon-Fri {8am 5pm}}
			variable special_days	{}
		}
	}

	#>>>
	method debug {debug} { #<<<
		if {$debug} {
			proc ?? script {uplevel #1 $script}
		} else {
			proc ?? args {}
		}
	}

	#>>>
	method _clear_caches {} { #<<<
		set dow_range_cache	{}
		unset -nocomplain office_hours_compiled
	}

	#>>>
	method configure {args} { #<<<
		my _clear_caches
		tailcall cfg configure {*}$args
	}

	#>>>
	forward cget		cfg cget

	method _compile_times {daystart times} { #<<<
		if {[llength $times] % 2 != 0} {
			error "Times must be a list of pairs of times like {8am 5pm} or {8am 11:30am 1pm 5pm}"
		}
		set offsets	{}
		foreach time $times {
			set offset	[- [clock scan $time -base $daystart] $daystart]
			if {$offset == -1} {
				# Special case for times like 24:00
				set offset [- [clock add $daystart 1 day] $daystart]
			}
			lappend offsets	$offset
		}
		set offsets
	}

	#>>>
	method _office_hours_compiled {} { #<<<
		# DST safe: times are left text form, not resolved
		if {![info exists office_hours_compiled]} {
			set office_hours_compiled	{}
			foreach {dow_range times} [cfg get office_hours] {
				switch -regexp -matchvar m -- $dow_range {
					^(.*?)-(.*)$ {
						lassign $m - low high
						set range_low	[clock format [clock scan $low] -format %w]
						set range_high	[clock format [clock scan $high] -format %u]

					}

					default {
						set range_low	[clock format [clock scan $dow_range] -format %u]
						set range_high	[clock format [clock scan $dow_range] -format %u]
					}
				}

				lappend office_hours_compiled $range_low $range_high $times
			}
		}
		set office_hours_compiled
	}

	#>>>
	method _normal_dow_range daystart { #<<<
		set dow	[clock format $daystart -format %u]	;# Sunday == 7
		if {![dict exists $dow_range_cache $dow]} {
			set found	0
			foreach {low high times} [my _office_hours_compiled] {
				if {[<= $low $dow $high]} {
					dict set dow_range_cache $dow $times
					set found	1
					break
				}
			}
			if {!($found)} {
				dict set dow_range_cache $dow {}
			}
		}
		dict get $dow_range_cache $dow
	}

	#>>>
	method _gaps daystart { #<<<
		set gaps	{}

		if {[cfg get special_days] eq {}} {
			set special	normal
		} else {
			set special	[uplevel #0 [list {*}[cfg get special_days] $daystart]]
		}
		if {[string is boolean -strict $special]} {
			set special	[expr {$special ? "holiday" : "normal"}]
		}
		switch -exact -- $special {
			holiday	{set times	{}}
			normal	{set times	[my _normal_dow_range $daystart]}
			default	{set times	$special}
		}

		foreach {a b} [list \
				0 \
				{*}[my _compile_times $daystart $times] \
				[- [clock add $daystart 1 day] $daystart] \
		] {
			lappend gaps \
					[+ $daystart $a] \
					[+ $daystart $b -1]
		}

		set gaps
	}

	#>>>
	method offset {interval {from now}} { #<<<
		if {$from eq "now"} {
			set from	[clock seconds]
		} else {
			if {![string is digit -strict $from]} {
				set from	[clock scan $from]
			}
		}
		?? {puts "Calculating ($interval) offset from \"[clock format $from]\""}

		# Compute the interval manually rather than using clock add to avoid
		# things like DST adjustments messing with the absolute interval value
		if {![regexp {^\s*((?:\+|-)?[0-9]+(?:\.[0-9]+)?)\s+(.*?)s?\s*$} $interval - count units]} {
			error "Cannot parse interval \"$interval\""
		}
		if {![string is double -strict $count]} {
			error "Invalid count in interval, must be an integer"
		}
		set step_mode	seconds
		switch -- $units {
			second	{set remaining	$count}
			minute	{set remaining	[* $count 60]}
			hour	{set remaining	[* $count 3600]}
			day {
				# Tricky
				set step_mode	days
				set remaining	$count
			}
			week - month - year {
				set from		[clock add $from $count $units]
				set remaining	0
			}

			default {
				error "Invalid unit in interval, should be one of {second minute hour day week month year} or their plural forms"
			}
		}

		set remaining	[expr {int(ceil($remaining))}]

		if {$remaining < 0} {
			# TODO: some negative intervals might be useful - to calculate back
			# from a future "from" for instance
			# Could be done by setting some direction vectors used later in
			# clock adds to step the pointer, and work out things like daystart
			# (or dayend in the negative case)
			error "Negative intervals not allowed"
		}

		set pointer	$from

		?? {
			puts "units: $units"
			puts "remaining: $remaining $step_mode"
			puts "pointer: \"[clock format $pointer]\""
		}

		while {1} {
			set daystart	[clock scan 00:00:00 -base $pointer]
			set gaps		[my _gaps $daystart]
			?? {
				puts "-------------------------------------------------"
				puts "While loop iteration [incr _iter], pointer: \"[clock format $pointer]\""
				puts "\tdaystart: \"[clock format $daystart]\""
				puts "\tremaining: $remaining"
				#foreach {a b} $gaps {
				#	puts "\tgap \"[clock format $a]]\" - \"[clock format $b]\""
				#}
			}

			if {$step_mode eq "days" && $remaining > 0} {
				if {[llength $gaps] > 2} {
					# gaps is a 2 element list if there are no business hours
					# in this day
					if {$pointer > [lindex $gaps end-1]} {
						set pointer	[+ [lindex $gaps end] 1]
						continue
					} else {
						incr remaining -1
					}
				}
				set pointer	[clock add $pointer 1 day]
				continue
			}

			foreach {gap_start gap_end} $gaps {
				?? {
					puts "\t=== Processing gap \"[clock format $gap_start]\" - \"[clock format $gap_end]\""
				}
				if {$pointer + $remaining < $gap_start} {
					?? {
						puts "\t\t-> Enough time remains before the start of the gap, advancing pointer \"[clock format $pointer]\" by $remaining seconds to \"[clock format [+ $pointer $remaining]]\" and calling it a day"
					}
					incr pointer	$remaining
					set remaining	0
					return $pointer
				} elseif {$pointer < $gap_start} {
					?? {
						puts "\t\t-> Pointer is before the next gap, advancing to gap_end+1: \"[clock format [+ $gap_end 1]]\", and reducing remaining by [- $gap_start $pointer] seconds to [- $remaining [- $gap_start $pointer]]"
					}
					incr remaining	-[- $gap_start $pointer]
					set pointer		[+ $gap_end 1]
				} elseif {$pointer <= $gap_end} {
					?? {
						puts "\t\t-> Pointer is in the gap, advancing to gap_end+1"
					}
					set pointer		[+ $gap_end 1]
				} else {
					?? {
						puts "\t\t-> Pointer is beyond the gap_end, doing nothing"
					}
				}
				?? {puts "\t    <- Pointer \"[clock format $pointer]\""}
			}
		}
	}

	#>>>
	method in_office_hours {{time now}} { #<<<
		if {$time eq "now"} {
			set time	[clock seconds]
		} else {
			if {![string is digit -strict $time]} {
				set time	[clock scan $time]
			}
		}

		set daystart	[clock scan 00:00:00 -base $time]
		foreach {gap_start gap_end} [my _gaps $daystart] {
			if {$time < $gap_start} {
				return 1
			} elseif {$time <= $gap_end} {
				return 0
			}
		}
		return 0
	}

	#>>>
}


