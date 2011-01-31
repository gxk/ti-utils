#!/bin/sh

# Bootlevels
# 1 - start only inetd			0001
# 2 - load mav80211			0010
# 4 - load driver			0100
# 8 - up dev, load wpa_supplicant	1000

go_version="0.3"
usage()
{
	echo -e "\tUSAGE:\n\t    `basename $0` <option>"
	echo -e "\t\t-b <value> - bootlevel, where\n\t\t\t7-PLT boot"
	echo -e "\t\t\t15-full boot"
	echo -e "\t\t-d <value> - debuglevel, where"
	echo -e "\t\t\tDEBUG_IRQ       = BIT(0)
		\tDEBUG_SPI       = BIT(1)
		\tDEBUG_BOOT      = BIT(2)
		\tDEBUG_MAILBOX   = BIT(3)
		\tDEBUG_TESTMODE  = BIT(4)
		\tDEBUG_EVENT     = BIT(5)
		\tDEBUG_TX        = BIT(6)
		\tDEBUG_RX        = BIT(7)
		\tDEBUG_SCAN      = BIT(8)
		\tDEBUG_CRYPT     = BIT(9)
		\tDEBUG_PSM       = BIT(10)
		\tDEBUG_MAC80211  = BIT(11)
		\tDEBUG_CMD       = BIT(12)
		\tDEBUG_ACX       = BIT(13)
		\tDEBUG_SDIO      = BIT(14)
		\tDEBUG_FILTERS   = BIT(15)
		\tDEBUG_ADHOC     = BIT(16)
		\tDEBUG_ALL       = ~0"
	echo -e "\t\t-m <value> - set MAC address"
	echo -e "\t\t-ip [value] - set IP address"
	echo -e "\t\t-v - get script version"
	echo -e "\t\t-h - get this help"
}

i=0
nbr_args=$#
bootlevel=0
dbg_lvl=0
ref_clk=0
mac_addr="08:00:28:90:64:31"
ip_addr="192.168.1.1"
set_ip_addr=0
while [ "$i" -lt "$nbr_args" ]
do
	case $1 in
		-b) bootlevel=$2
		nbr_args=`expr $nbr_args - 1`
		shift
		;;
		#-r) ref_clk=$2
		#nbr_args=`expr $nbr_args - 1`
		#shift
		#;;
		-d) dbg_lvl=$2
		nbr_args=`expr $nbr_args - 1`
		shift
		;;
		-m) mac_addr=$2
		nbr_args=`expr $nbr_args - 1`
		shift
		;;
		-ip) set_ip_addr=`expr $set_ip_addr + 1`
			case $2 in
				"") echo -e "using default ip address"
				;;
				-*) echo -e "this is another option"
				;;
				*) ip_addr=$2
				nbr_args=`expr $nbr_args - 1`
				shift
				;;
			esac
		;;
		-v)
		echo -e "\tgo.sh version $go_version"
		;;
		-h) usage
		exit 0
		;;
		*) echo -e "\tNothing to do"
		;;
	esac
	i=`expr $i + 1`
	shift
done

#if [ "$bootlevel" -eq "0" ]; then
#	exit 0
#fi

stage_uno=0
stage_due=0
stage_quattro=0
stage_otto=0
case $bootlevel in
	1) stage_uno=`expr $stage_uno + 1`
	;;
	2) stage_due=`expr $stage_due + 1`
	;;
	3) stage_uno=`expr $stage_uno + 1`
	   stage_due=`expr $stage_due + 1`
	;;
	4) stage_quattro=`expr $stage_quattro + 1`
	;;
	6) stage_due=`expr $stage_due + 1`
	   stage_quattro=`expr $stage_quattro + 1`
	;;
	7) stage_uno=`expr $stage_uno + 1`
	   stage_due=`expr $stage_due + 1`
	   stage_quattro=`expr $stage_quattro + 1`
	;;
	8) stage_otto=`expr $stage_otto + 1`
	;;
	12) stage_quattro=`expr $stage_quattro + 1`
           stage_otto=`expr $stage_otto + 1`
	;;
	15) stage_uno=`expr $stage_uno + 1`
	   stage_due=`expr $stage_due + 1`
	   stage_quattro=`expr $stage_quattro + 1`
	   stage_otto=`expr $stage_otto + 1`
	;;
esac

echo -e "\t------------         ------------\n"
echo -e "\t---===<<<((( WELCOME )))>>>===---\n"
echo -e "\t------------         ------------\n"

if [ "$stage_uno" -ne "0" ]; then
	echo 8 > /proc/sys/kernel/printk
	/libexec/inetd /etc/inetd.conf &

	mount -t debugfs debugfs /debug

	echo -e "\t---===<<<((( Level 1 )))>>>===---\n"
fi

if [ "$stage_due" -ne "0" ]; then
	insmod /lib/modules/`uname -r`/kernel/net/wireless/cfg80211.ko
	insmod /lib/modules/`uname -r`/kernel/net/mac80211/mac80211.ko
	insmod /lib/modules/`uname -r`/kernel/lib/crc7.ko
	insmod /lib/modules/`uname -r`/kernel/drivers/base/firmware_class.ko

	echo -e "\t---===<<<((( Level 2 )))>>>===---\n"
fi

if [ "$stage_quattro" -ne "0" ]; then
	insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx.ko
	if [ "$ref_clk" -eq "0" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx_sdio.ko
	else
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx_sdio.ko ref_clk=$2
	fi
	sleep 1
	echo 1 > /debug/tracing/events/mac80211/enable
	#cat /debug/tracing/trace

	ifconfig wlan0 hw ether $mac_addr
	sleep 1
	#cat /debug/mmc2/ios

	echo -e "\t---===<<<((( Level 4 )))>>>===---\n"
fi

if [ "$stage_otto" -ne "0" ]; then
	ifconfig wlan0 up
	iw event > /var/log/iwevents &

	#wpa_supplicant -P/var/run/wpa_supplicant.pid -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 -f/var/log/wpa_supplicant.log &
	sleep 1
	#iw wlan0 cqm rssi -55 2
	#wpa_supplicant -ddt -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 -f/var/log/wpa.log &
	wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 &
	#python /usr/share/peripherals-test-autom/dut.py -v &

	echo -e "\t---===<<<((( Level 8 )))>>>===---\n"
fi

if [ "$dbg_lvl" -eq "1" ] && [ -e /debug/ieee80211/phy0/wl12xx/debug_level ]; then
	dbg_lvl=`cat /debug/ieee80211/phy0/wl12xx/debug_level`
	echo -e "\ndbg lvl: $dbg_lvl\n"
elif [ "$dbg_lvl" -ne "0" ] && [ -e /debug/ieee80211/phy0/wl12xx/debug_level ]; then
	echo "$dbg_lvl" > /debug/ieee80211/phy0/wl12xx/debug_level

	echo 'module wl12xx +p' > /debug/dynamic_debug/control
fi

if [ "$set_ip_addr" -ne "0" ]; then
	echo -e "Going to set IP $ip_addr"
	ifconfig wlan0 $ip_addr up
fi

exit 0
