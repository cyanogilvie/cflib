# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::in_tmp_dir {script {on_error ""}} { #<<<
	set oldpwd	[pwd]
	set tempfp	[file tempfile tmpdir]
	close $tempfp
	file delete $tmpdir
	file mkdir $tmpdir
	cd $tmpdir
	try {
		uplevel $script
	} on error {errmsg options} {
		puts [dict get $options -errorinfo]
		if {$on_error ne ""} {
			try {
				apply [list {errmsg options} $on_error] $errmsg $options
			} on error {terrmsg toptions} {
				puts stderr "Error in on_error script"
			}
		}
		dict incr options -level
		return -options $options $errmsg
	} finally {
		cd $oldpwd
		if {[info exists tmpdir] && [file exists $tmpdir]} {
			# TODO: paranoid checks
			file delete -force -- $tmpdir
		}
	}
}

#>>>
