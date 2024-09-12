# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::with_dir {dir script} {
	set hold	[pwd]
	set code	[catch {uplevel 1 $script} r]
	cd $hold
	return -code $code $r
}

