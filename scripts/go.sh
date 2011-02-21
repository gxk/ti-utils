#!/bin/sh

# Bootlevels
#   1 - start only inetd			0000 0001
#   2 - load mav80211				0000 0010
#   4 - load driver				0000 0100
#   8 - up dev, load wpa_supplicant		0000 1000
#  16 - create reference NVS            	0001 0000
#  32 - calibrate				0010 0000
#  64 - 1-command calibration			0100 0000

go_version="0.6"
usage()
{
	echo -e "\tUSAGE:\n\t    `basename $0` <option> [value]"
	echo -e "\t\t-b <value> - bootlevel, where\n\t\t\t7-PLT boot"
	echo -e "\t\t\t15-full boot"
	echo -e "\t\t-c <path to INI file> [path to install] - run calibration"
	echo -e "\t\t\twhere the default value for install path is "
	echo -e "\t\t\t/lib/firmware/wl1271-nvs.bin"
	echo -e "\t\t-d <value> - debuglevel, where"
	echo -e "\t\t\t  -1      - shows current value
\t\t\tDEBUG_IRQ       = BIT(0)
\t\t\tDEBUG_SPI       = BIT(1)
\t\t\tDEBUG_BOOT      = BIT(2)
\t\t\tDEBUG_MAILBOX   = BIT(3)
\t\t\tDEBUG_TESTMODE  = BIT(4)
\t\t\tDEBUG_EVENT     = BIT(5)
\t\t\tDEBUG_TX        = BIT(6)
\t\t\tDEBUG_RX        = BIT(7)
\t\t\tDEBUG_SCAN      = BIT(8)
\t\t\tDEBUG_CRYPT     = BIT(9)
\t\t\tDEBUG_PSM       = BIT(10)
\t\t\tDEBUG_MAC80211  = BIT(11)
\t\t\tDEBUG_CMD       = BIT(12)
\t\t\tDEBUG_ACX       = BIT(13)
\t\t\tDEBUG_SDIO      = BIT(14)
\t\t\tDEBUG_FILTERS   = BIT(15)
\t\t\tDEBUG_ADHOC     = BIT(16)
\t\t\tDEBUG_ALL       = ~0"
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
have_path_to_ini=0
path_to_ini=""
have_path_to_install=0
path_to_install="/lib/firmware/wl1271-nvs.bin"
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
		-c)
			if [ "$nbr_args" -lt "2" ]; then
				echo -e "missing arguments"
				exit 1
			fi

			bootlevel=66
			have_path_to_ini=`expr $have_path_to_ini + 1`
			path_to_ini=$2
			if [ "$nbr_args" -eq "2" ]; then
				echo -e "    The install path not provided"
				echo -e "    Use default ($path_to_install)"
				nbr_args=`expr $nbr_args - 1`
				shift
				break
			fi

			have_path_to_install=`expr $have_path_to_install + 1`
			path_to_install=$3
			nbr_args=`expr $nbr_args - 2`
			shift
			shift
		;;
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
		-ini)
			have_path_to_ini=`expr $have_path_to_ini + 1`
			path_to_ini=$2
			nbr_args=`expr $nbr_args - 1`
			shift
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
stage_sedici=0
stage_sessanta_quattro=0
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
	5) stage_uno=`expr $stage_uno + 1`
	   stage_quattro=`expr $stage_quattro + 1`
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
	16) stage_sedici=`expr $stage_sedici + 1`
	;;
	64) stage_sessanta_quattro=`expr $stage_sessanta_quattro + 1`
	;;
	66)
	    stage_due=`expr $stage_due + 1`
	    stage_sessanta_quattro=`expr $stage_sessanta_quattro + 1`
	;;
esac

echo -e "\t------------         ------------\n"
echo -e "\t---===<<<((( WELCOME )))>>>===---\n"
echo -e "\t------------         ------------\n"

if [ "$stage_uno" -ne "0" ]; then

	echo 8 > /proc/sys/kernel/printk

	if [ -e /libexec/inetd ]; then
		/libexec/inetd /etc/inetd.conf &
	fi

	if [ ! -e /debug/tracing ]; then
		mount -t debugfs debugfs /debug
	fi

	echo -e "\t---===<<<((( Level 1 )))>>>===---\n"
fi

if [ "$stage_due" -ne "0" ]; then

	run_it=`cat /proc/modules | grep "cfg80211"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/net/wireless/cfg80211.ko
	fi
	run_it=`cat /proc/modules | grep "mac80211"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/net/mac80211/mac80211.ko
	fi
	run_it=`cat /proc/modules | grep "crc7"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/lib/crc7.ko
	fi
	run_it=`cat /proc/modules | grep "firmware_class"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/base/firmware_class.ko
	fi

	echo -e "\t---===<<<((( Level 2 )))>>>===---\n"
fi

if [ "$stage_quattro" -ne "0" ]; then

	run_it=`cat /proc/modules | grep "wl12xx"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx.ko
		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx"
			exit 1
		fi
	fi
	echo -e "+++ Load wl12xx driver"
	run_it=`cat /proc/modules | grep "wl12xx_sdio"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx_sdio.ko
		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx_sdio"
			exit 1
		fi
	fi
	#insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx_sdio.ko ref_clk=$2
	sleep 1
	echo 1 > /debug/tracing/events/mac80211/enable
	#cat /debug/tracing/trace

	ifconfig wlan0 hw ether $mac_addr
	#sleep 1
	#cat /debug/mmc2/ios

	echo -e "\t---===<<<((( Level 4 )))>>>===---\n"
fi

if [ "$stage_otto" -ne "0" ]; then

	ifconfig wlan0 up
	if [ "$?" != "0" ]; then
		echo -e "Fail to start iface"
		exit 1
	fi

	iw event > /var/log/iwevents &

	#wpa_supplicant -P/var/run/wpa_supplicant.pid -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 -f/var/log/wpa_supplicant.log &
	sleep 1
	#iw wlan0 cqm rssi -55 2
	#wpa_supplicant -ddt -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 -f/var/log/wpa.log &
	wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 &
	#python /usr/share/peripherals-test-autom/dut.py -v &

	echo -e "\t---===<<<((( Level 8 )))>>>===---\n"
fi

if [ "$stage_sedici" -ne "0" ] && [ "$have_path_to_ini" -ne "0" ]; then
	./calibrator set ref_nvs $have_path_to_ini
fi

#
# 1-command calibration
# parameters are INI file, path where to install NVS (default /lib/firmware)
#

if [ "$stage_sessanta_quattro" -ne "0" ]; then

	if [ "$have_path_to_ini" -eq "0" ]; then
		echo -e "Missing ini file parameter"
		exit 1
	fi

	# 1. unload wl12xx kernel modules
	run_it=`cat /proc/modules | grep "wl12xx_sdio"`
	if [ "$run_it" != "" ]; then
		rmmod wl12xx_sdio
	fi
	run_it=`cat /proc/modules | grep "wl12xx"`
	if [ "$run_it" != "" ]; then
		rmmod wl12xx
	fi

	# 2. create reference NVS file with default MAC (0B:AD:DE:AD:BE:EF)
	echo -e "+++ Create reference NVS with INI $path_to_ini"
	run_it=`./calibrator set ref_nvs $path_to_ini`

	# 3. copy NVS to proper place
	echo -e "+++ Copy reference NVS file to $path_to_install"
	run_it=`cp -f ./new-nvs.bin $path_to_install`

	# 4. load wl12xx kernel modules
	echo -e "+++ Load wl12xx driver"
	run_it=`cat /proc/modules | grep "wl12xx"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx.ko
		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx"
			exit 1
		fi
	fi
	echo -e "+++ Load wl12xx driver"
	run_it=`cat /proc/modules | grep "wl12xx_sdio"`
	if [ "$run_it" == "" ]; then
		insmod /lib/modules/`uname -r`/kernel/drivers/net/wireless/wl12xx/wl12xx_sdio.ko
		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx_sdio"
			exit 1
		fi
	fi

	# 5. calibrate
	echo -e "+++ Calibrate"
	./calibrator wlan0 plt power_mode on
	if [ "$?" != "0" ]; then
		echo -e "Fail to set power mode to on"
		exit 1
	fi

	./calibrator wlan0 plt tune_channel 0 7
	if [ "$?" != "0" ]; then
		echo -e "Fail to tune channel"
		exit 1
	fi

	run_it=`cat $path_to_ini | grep "RxTraceInsertionLoss_5G"`
	if [ "$run_it" != "" ]; then
		./calibrator wlan0 plt tx_bip 1 1 1 1 1 1 1 1 $path_to_install
		if [ "$?" != "0" ]; then
			echo -e "Fail to calibrate"
			exit 1
		fi
	else
		./calibrator wlan0 plt tx_bip 1 0 0 0 0 0 0 0 $path_to_install
		if [ "$?" != "0" ]; then
			echo -e "Fail to calibrate"
			exit 1
		fi
	fi

	./calibrator wlan0 plt power_mode off
	if [ "$?" != "0" ]; then
		echo -e "Fail to set power mode to off"
		exit 1
	fi

	# 6. unload wl12xx kernel modules
	rmmod wl12xx_sdio wl12xx

	# 7. copy calibrated NVS file to proper place
	echo -e "+++ Copy calibrated NVS file to $path_to_install"
	run_it=`cp -f ./new-nvs.bin $path_to_install`

	# 7. load wl12xx kernel modules

	sh $0 -b 5

	echo -e "\n\tDear Customer, you are ready to use our calibrated device\n"
fi

if [ "$dbg_lvl" -eq "-1" ] && [ -e /sys/module/wl12xx/parameters/debug_level ]; then
	dbg_lvl=`cat /sys/module/wl12xx/parameters/debug_level`
	echo -e "\ndbg lvl: $dbg_lvl\n"
elif [ "$dbg_lvl" -ne "0" ] && [ -e /sys/module/wl12xx/parameters/debug_level ]; then
	echo "$dbg_lvl" > /sys/module/wl12xx/parameters/debug_level

	echo 'module wl12xx +p' > /debug/dynamic_debug/control
fi

if [ "$set_ip_addr" -ne "0" ]; then
	echo -e "Going to set IP $ip_addr"
	ifconfig wlan0 $ip_addr up
fi

exit 0
