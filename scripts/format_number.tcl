proc cflib::format_number {n {sep ,}} {
	if {![regexp {^([0-9]{0,3})((?:[0-9]{3})*)(\.[0-9]+)?$} $n - l r d]} {
		error "Not an integer: $n"
	}
	string cat [join [list {*}$l {*}[regexp -all -inline ... $r]] $sep] $d
}
