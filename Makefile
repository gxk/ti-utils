CC = $(CROSS_COMPILE)gcc
CFLAGS = -O2
CFLAGS += -DCONFIG_LIBNL20
CFLAGS += -I$(NFSROOT)/include

LDFLAGS += -L$(NFSROOT)/lib
LIBS += -lnl -lnl-genl -lm

OBJS = nvs.o misc_cmds.o calibrator.o plt.o

%.o: %.c calibrator.h nl80211.h plt.h nvs_dual_band.h
	$(CC) $(CFLAGS) -c -o $@ $<

all: $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o calibrator
	@echo -e "\n\tMake sure to use reference-nvs.bin if needed\n"

clean:
	@rm -f *.o calibrator
