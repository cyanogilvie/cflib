# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::readfile {fn {mode text}} {
	try {
		set fp	[open $fn r]
		if {$mode eq "binary"} {
			chan configure $fp \
					-translation binary \
					-encoding binary
		}
		set dat	[read $fp]

		return $dat
	} finally {
		if {[info exists fp] && $fp in [chan names]} {
			close $fp
		}
	}
}


