namespace eval ::oo::Helpers::cflib {
	proc scope {varname} {
		join [list [uplevel 1 {namespace current}] $varname] ::
	}
}

