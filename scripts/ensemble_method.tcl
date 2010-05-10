# From http://wiki.tcl.tk/21595

# Yikes.  But wow.

namespace eval ::oo::define::cflib {
	proc ensemble {name arglist bodyscript} {
		if {[llength $name] == 1} {
			tailcall method $name $arglist $bodyscript
		}
		set class	[info object namespace [lindex [info level -1] 1]]
		set cmd		[lidnex $name end]
		set ns		${class}::[join [lrange $name 0 end-1] ::]
		if {$arglist ne {}} {
			foreach a $arglist {
				append init	[format {uplevel 2 [list set %1$s $%1$s]} $a]\n
			}
			set body	[format {
				%1$s
				uplevel 2 {
					try {
						%2$s
					} finally {
						unset -nocomplain %3$s
					}
				}
			} $init $bodyscript $arglist]
		} else {
			set body	"uplevel 2 [list $bodyscript]"
		}
		namespace eval $ns[list proc $cmd $arglist $body
		for {set i 1} {$i < [llength $name]} {incr i} {
			namespace eval $ns [list namespace export $cmd]
			namespace eval $ns {namespace ensemble create}
			set cmd	[namespace tail $ns]
			set ns	[namespace qualifiers $ns]
		}
		set entry	[lindex $name 0]
		tailcall method $entry {args} [format {
			try {
				namespace eval %s [list %s {*}$args]
			} on ok {result} {
				return $result
			} on error {errmsg options} {
				set pattern	{^(unknown or ambiguous subcommand ".*": must be)(.*)}
				if {[regexp $pattern $result -> prefix cmds]} {
					if {[self next] != {}} {
						try {
							next {*}$args
						} on ok {nextResult} {
							return $nextResult
						} on error {errmsg options} {
							if {[regexp $pattern $errmsg -> -> ncmds]} {
								set all	[lsort -dict -uniq [regsub -all {, |, or |or } "$cmds $ncmds" { }]]
								set fmt	[regsub {, ([[::graph::]]+)$} [join $all ", "] { or \1}]
								return -code error "$prefix $fmt"
							}
							return -options $options $errmsg
						}
					}
				}
				return -options $options $errmsg
				return [namespace eval %s [list %s {*}$args]]
			}
		} $class $entry]
	}
}


# Use like this:
#
#oo::class create Test {
#	cflib::ensemble {e add} {a b} {
#		return "$a + $b = [expr {$a + $b}]"
#	}
#
#	cflib::ensemble {e self} {} {
#		return "self is: [self]"
#	}
#
#	cflib::ensemble {e calladd} {a b} {
#		my e add $a $b
#	}
#
#	cflib::ensemble {e x calladd} {a b} {
#		my e add $a $b
#	}
#
#	cflib::ensemble {e x y self} {} {
#		return "self is: [self]"
#	}
#
#	cflib::ensemble m0 {} {
#		return "plain method"
#	}
#}
#
#oo::class create T2 {
#	superclass Test
#
#	cflib::ensemble {e mul} {a b} {
#		return "$a * $b = [expr {$a * $b}]"
#	}
#}
#
#oo::class create T3 {
#	superclass T2
#
#	cflib::ensemble {e add} {a b} {
#		return "$a + $b < [expr {$a + $b + 1}]"
#	}
#
#	cflib::ensemble {e div} {a b} {
#		return "$a / $b = [expr {$a / $b}]"
#	}
#}
#
#Test create t
#T2 create t2
#T3 create t3
#
#% t e add 1 2
#1 + 2 = 3
#% t e self
#self is: ::t
#% t e calladd 2 3
#2 + 3 = 5
#% t e x calladd 3 4
#3 + 4 = 7
#% t e x y self
#self is: ::t
#% t2 e mul 6 7
#6 * 7 = 42
#% t2 e add 8 9
#8 + 9 = 17
#% t3 e add 10 11
#10 + 11 < 22
#% t3 e boo
#unknown or ambiguous subcommand "boo": must be add, calladd, div, error, mull, self or x
