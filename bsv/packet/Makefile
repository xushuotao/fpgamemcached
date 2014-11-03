
bsim: Test.bsv
	 bsc -show-schedule -aggressive-conditions -sim -g mkTest -u Test.bsv
	bsc -show-schedule -aggressive-conditions -sim -e mkTest -o mkTest

all: bsim
	./mkTest
