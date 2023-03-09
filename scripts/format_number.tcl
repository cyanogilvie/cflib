proc cflib::format_number {n {sep ,}} {
	if {![regexp {^([0-9]*)(\.[0-9]+)?$} $n - a d]} {
		error "Not an number: $n"
	}
	regexp {^([0-9]{0,3})((?:[0-9]{3})*)$} $a - l r
	string cat [join [list {*}$l {*}[regexp -all -inline ... $r]] $sep] $d
}
