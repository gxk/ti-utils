CC = $(CROSS_COMPILE)gcc
CFLAGS = -O2
CFLAGS += -DCONFIG_LIBNL20
CFLAGS += -I$(NFSROOT)/include

LDFLAGS += -L$(NFSROOT)/lib
LIBS += -lnl -lnl-genl -lm

OBJS = nvs.o misc_cmds.o calibrator.o plt.o ini.o

%.o: %.c calibrator.h nl80211.h plt.h nvs_dual_band.h
	$(CC) $(CFLAGS) -c -o $@ $<

all: $(OBJS) 
	$(CC) $(LDFLAGS) --static $(OBJS) $(LIBS) -o calibrator.bin
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o calibrator

install:
	@cp -f ./calibrator $(NFSROOT)/home/root
	@cp -f ./calibrator.bin $(NFSROOT)/home/root

clean:
	@rm -f *.o calibrator
