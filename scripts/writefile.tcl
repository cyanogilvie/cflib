# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::writefile {fn data {mode "text"}} {
	try {
		set fp	[open $fn w]
		if {$mode eq "binary"} {
			chan configure $fp \
					-translation binary \
					-encoding binary
		}
		chan puts -nonewline $fp $data
	} finally {
		if {[info exists fp] && $fp in [chan names]} {
			close $fp
		}
	}
}


