TBUILD=`which tbuild`

all:
	$(TBUILD) build all

clean:
	$(TBUILD) clean

install:
	$(TBUILD) install

test: all
	#$(TBUILD) run -- tests/all.tcl $(TESTFLAGS)
	`which cfkit8.6` tests/all.tcl $(TESTFLAGS)

remove:
	$(TBUILD) remove
