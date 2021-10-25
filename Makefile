TBUILD="cftcl.tbuild-lite"
TCLSH="cftcl"

all:
	$(TBUILD) build all

clean:
	$(TBUILD) clean

install:
	$(TBUILD) install

test: all
	#$(TBUILD) run -- tests/all.tcl $(TESTFLAGS)
	$(TCLSH) tests/all.tcl $(TESTFLAGS)

remove:
	$(TBUILD) remove
