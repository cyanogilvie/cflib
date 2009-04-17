# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

proc cflib::fullynormalize {fn} {
	set fqfn	[file normalize $fn]

	set patience	20
	set seen		{}
	while {[file type $fqfn] eq "link"} {
		set fqfn	[file normalize [file readlink $fqfn]]
		if {[incr patience -1] <= 0} {
			error "Too many symlinks: $fn"
		}
		if {$fqfn in $seen} {
			error "Circular symlinks: $fn"
		}
	}

	return $fqfn
}


