namespace eval ::cflib::dict_bind_saved {}
proc cflib::dict_bind {var cmd} {
	upvar 1 $var dictvar
	if {![info exists dictvar]} {error "\"$var\" doesn't exist"}

	set ns	[uplevel 1 {namespace current}]
	if {$ns eq "::"} {set ns ""}

	set fqcmd	${ns}::$cmd

	# If the bind command already exists, save it in to a temporary namespace
	if {[info commands $fqcmd] ne ""} {
		set saved_name	::cflib::dict_bind_saved::saved_cmd_[incr ::cflib::dict_bind_seq]
		rename $fqcmd $saved_name
	} else {
		set saved_name	""
	}

	interp alias {} $fqcmd {} dict get [uplevel 1 [list set $var]]

	trace add variable dictvar unset [list apply {
		{fqcmd saved_name args} {
			try {
				rename $fqcmd {}
				if {$saved_name ne ""} {
					rename $saved_name $fqcmd
				}
			} on error {errmsg options} {
				log error "Error restoring dict_bind state: [dict get $options -errorinfo]"
			}
		}
	} $fqcmd $saved_name]
}
