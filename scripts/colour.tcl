proc cflib::c {args} {
	set map {
		black		30
		red			31
		green		32
		yellow		33
		blue		34
		purple		35
		cyan		36
		white		37
		bg_black	40
		bg_red		41
		bg_green	42
		bg_yellow	43
		bg_blue		44
		bg_purple	45
		bg_cyan		46
		bg_white	47
		inverse		7
		bold		5
		underline	4
		bright		1
		norm		0
	}
	join [lmap t $args {
		if {![dict exists $map $t]} continue
		set _ "\[[dict get $map $t]m"
	}] {}
}

