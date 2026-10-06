# Requires jitc 0.8+ (libslimcc, for C2Y defer); without it
# cflib::format_number isn't defined
if {![catch {package require jitc 0.8}]} {
	interp alias {} ::cflib::format_number {} ::jitc::capply {
		options	{-Wall -Werror -O2}
		filter	{jitc::re2c -W --case-ranges --tags -Wno-nondeterministic-tags}
		code {
			//@begin=c@
			#include <string.h>
			#include <stddefer.h>

			// Every exit returns: the deferred free releases ds on errors, and
			// is a no-op after Tcl_DStringResult has moved it to the result
			#define RETURN_DS	do { Tcl_DStringResult(interp, &ds); return TCL_OK; } while (0)

			OBJCMD(fmtnum) {
				enum {A_cmd, A_N, A_args, A_SEP=A_args, A_objc};

				if (objc < A_args || objc > A_objc) {
					Tcl_WrongNumArgs(interp, A_cmd+1, objv, "n ?sep?");
					return TCL_ERROR;
				}

				Tcl_Size		len;
				const char*		str = Tcl_GetStringFromObj(objv[A_N], &len);
				const char*		s = str;
				const char*		YYMARKER;
				const char		*n1, *n2, *e1, *e2, *d1, *d2, *d3, *d4;
				#define DEFAULT_SEP	"\u2009"
				const char*		sep = DEFAULT_SEP;	// \u2009 - thin space
				Tcl_Size		seplen = sizeof DEFAULT_SEP -1;
				/*!types:re2c*/
				/*!stags:re2c format = "const char*	@@;\n"; */

				if (objc > A_SEP)
					sep = Tcl_GetStringFromObj(objv[A_SEP], &seplen);

				Tcl_DString		ds;
				Tcl_DStringInit(&ds);
				defer Tcl_DStringFree(&ds);

				/*!re2c
					re2c:yyfill:enable		= 0;
					re2c:define:YYCTYPE		= "char";
					re2c:define:YYCURSOR	= "s";

					end		= [\x00];
					digit	= [0-9];
					sign	= [-+];
					number	= "0"
							| [1-9] digit*;
					passthrough	= sign? "." digit+;
					inf		= "+"? 'Inf';
					neginf	= "-" 'Inf';
					nan		= 'NaN';

					enotation	= sign? "0"* @n1 number @n2 ("." @d1 digit+ @d2)? 'e' sign? @e1 number
								| sign? "." @d3 digit+ @d4 'e' sign? @e2 number;

					sign? "0"* @n1 number @n2 ("." digit+)? end {
						const int	len = n2-n1;
						const char*	p = n1;
						const int	mod3 = len % 3;

						if (str[0] == '-')
							Tcl_DStringAppend(&ds, "-", 1);

						if (mod3 > 0) {
							//fprintf(stderr, "Appending leading partial group: (%.*s)[%d]\n", mod3, p, mod3);
							Tcl_DStringAppend(&ds, p, mod3);
							p += mod3;
							if (p < n2)
								Tcl_DStringAppend(&ds, sep, seplen);
						}
						if (p < n2) {
							for (;;) {
								//fprintf(stderr, "Appending next group (%.*s)\n", 3, p);
								Tcl_DStringAppend(&ds, p, 3);
								p += 3;
								if (p >= n2) break;
								Tcl_DStringAppend(&ds, sep, seplen);
							}
						}

						if (*p == '.') {
							//fprintf(stderr, "Appending tail: %ld\n", s-p-1);
							Tcl_DStringAppend(&ds, ".", 1);
							p++;
							while (p+3 < s-1) {
								Tcl_DStringAppend(&ds, p, 3);
								Tcl_DStringAppend(&ds, sep, seplen);
								p += 3;
							}
							if (p < s-1)
								Tcl_DStringAppend(&ds, p, s-p-1);
						}

						RETURN_DS;
					}

					enotation end {
						const char*		e = e1 ? e1 : e2;
						const int		explen = s-e-1;
						const char*		p = e;
						int				exp = 0;
						Tcl_DString		tmp;

						if (d3) {
							d1 = d3;
							d2 = d4;
						}

						if (n1 == NULL) {
							n1 = str;
							n2 = str;
						}

						if (explen > 9) THROW_ERROR("Exponent too large");
						while (p < s-1) exp = exp*10 + (*p++ - '0');
						if (exp > 1000) THROW_ERROR("Exponent too large");
						if (e[-1] == '-') exp *= -1;

						int		decimal_offset = n2 - n1 + exp;

						Tcl_DStringInit(&tmp);
						defer Tcl_DStringFree(&tmp);
						if (decimal_offset <= 0) {
							const int	zeropad = -decimal_offset + 1;
							for (int i=0; i<zeropad; i++) Tcl_DStringAppend(&tmp, "0", 1);
							decimal_offset = 1;
						}
						Tcl_DStringAppend(&tmp, n1, n2-n1);
						if (d1) Tcl_DStringAppend(&tmp, d1, d2-d1);

						const int tmplen = Tcl_DStringLength(&tmp);
						if (tmplen <= decimal_offset) {
							const int	zeropad = decimal_offset - tmplen + 1;
							for (int i=0; i<zeropad; i++) Tcl_DStringAppend(&tmp, "0", 1);
						}

						p = Tcl_DStringValue(&tmp);
						const char*	dp = p + decimal_offset;
						const char*	end = p + Tcl_DStringLength(&tmp);

						// Trim superfluous leading zeros
						while (*p == '0' && decimal_offset > 1) {
							p++;
							decimal_offset--;
						}

						const int	mod3 = decimal_offset % 3;

						if (str[0] == '-')
							Tcl_DStringAppend(&ds, "-", 1);

						if (mod3 > 0) {
							//fprintf(stderr, "Appending leading partial group: (%.*s)[%d]\n", mod3, p, mod3);
							Tcl_DStringAppend(&ds, p, mod3);
							p += mod3;
							if (p < dp)
								Tcl_DStringAppend(&ds, sep, seplen);
						}
						if (p < dp) {
							for (;;) {
								//fprintf(stderr, "Appending next group (%.*s)\n", 3, p);
								Tcl_DStringAppend(&ds, p, 3);
								p += 3;
								if (p >= dp) break;
								Tcl_DStringAppend(&ds, sep, seplen);
							}
						}

						Tcl_DStringAppend(&ds, ".", 1);
						while (p+3 < end) {
							Tcl_DStringAppend(&ds, p, 3);
							Tcl_DStringAppend(&ds, sep, seplen);
							p += 3;
						}
						if (p < end)
							Tcl_DStringAppend(&ds, p, end-p);

						RETURN_DS;
					}

					passthrough end {
						Tcl_DStringAppend(&ds, str, len);
						RETURN_DS;
					}

					inf end {
						Tcl_DStringAppend(&ds, "Inf", 3);
						RETURN_DS;
					}

					neginf end {
						Tcl_DStringAppend(&ds, "-Inf", 4);
						RETURN_DS;
					}

					nan end {
						Tcl_DStringAppend(&ds, "NaN", 3);
						RETURN_DS;
					}

					* {THROW_ERROR("Not a number \"", str, "\"");}
				*/
			}
			//@end=c@
		}
	} fmtnum
}
