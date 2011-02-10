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
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o calibrator
	$(CC) -static $(LDFLAGS) $(OBJS) $(LIB) -o calibrator.bin

install:
	@cp -f ./calibrator $(NFSROOT)/home/root

clean:
	@rm -f *.o calibrator
