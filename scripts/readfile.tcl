# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::readfile {fn {mode text}} {
	set handle	[open $fn r]
	try {
		if {$mode eq "binary"} {
			chan configure $handle \
					-translation binary \
					-encoding binary
		}
		chan read $handle
	} finally {
		chan close $handle
	}
}


