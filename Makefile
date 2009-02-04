VER=1.0

TM_FILES=\
		 init.tcl \
		 scripts/pclass.tcl \
		 scripts/baselog.tcl \
		 scripts/refcounted.tcl

all: tm

tm: init.tcl scripts/*.tcl
	install -d tm
	cat $(TM_FILES) > tm/cflib-$(VER).tm

install: tm
	rsync -avP tm/* ../tm

clean:
	-rm -rf tm
