# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::writefile {fn data {mode "text"}} {
	set handle	[open $fn w]
	try {
		if {$mode eq "binary"} {
			chan configure $handle \
					-translation binary \
					-encoding binary
		}
		chan puts -nonewline $handle $data
	} finally {
		chan close $handle
	}
}


