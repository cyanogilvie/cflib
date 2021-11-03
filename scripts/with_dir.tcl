# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::with_dir {dir script} {
	set hold	[pwd]
	try {
		uplevel 1 $script
	} on break {r o} - on continue {r o} {
		dict incr o -level 1
		return -options $o $r
	} on return {r o} {
		dict incr o -level 1
		dict set o -code return
		return -options $o $r
	} finally {
		cd $hold
	}
}

