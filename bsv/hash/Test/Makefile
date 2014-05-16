
S2H = SimpleRequest
H2S = SimpleIndication
BSVFILES = Top.bsv Simple.bsv ../JenkinsHash.bsv
CPPFILES = testsimple.cpp ../jenkins_sw/jenkins_hash.c
Dma = 
PINS = Std


XBSVDIR=/home/shuotao/fpgamemcached/xbsv
BOARD=bluesim
TOP=$(XBSVDIR)/bsv/BsimTop
MKTOP=mkBsimTop


build:
	$(XBSVDIR)/genxpsprojfrombsv -B$(BOARD) -p $(BOARD) -x $(MKTOP) \
	$(foreach s2h, $(S2H), -s2h $(s2h)) \
	$(foreach h2s, $(H2S), -h2s $(h2s)) \
	$(foreach f, $(CPPFILES), -s $f) \
	-t $(TOP).bsv $(XBSVFLAGS) $(BSVFILES)

