# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::in_tmp_dir {script} { #<<<
	set oldpwd	[pwd]
	set tempfp	[file tempfile tmpdir]
	close $tempfp
	file delete $tmpdir
	file mkdir $tmpdir
	cd $tmpdir
	try {
		uplevel $script
	} on error {errmsg options} {
		dict incr options -level
		return -options $options $errmsg
	} on ok {res} {
		return $res
	} finally {
		cd $oldpwd
		if {[info exists tmpdir] && [file exists $tmpdir]} {
			# TODO: paranoid checks
			file delete -force -- $tmpdir
		}
	}
}

#>>>
