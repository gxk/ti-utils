#!/bin/sh

# PLT utility for TI's wireless driver wl12xx
#
# See README and COPYING for more details

usage()
{
	echo -e "\tUSAGE:\n\t    `basename $0` <option> [value]"
	#echo -e "\t\t-b <value> - bootlevel, where\n\t\t\t7-PLT boot"
	#echo -e "\t\t\t15-full boot"
	echo -e "\t\t-c <path to INI file> [MAC address] -" \
"run calibration"
	echo -e "\t\t-c2 <path to INI file> <path to INI file> " \
"[MAC address] - run calibration with 2 FEMs"
	echo -e "\t\t\twhere the default value for install path is "
	echo -e "\t\t\t/lib/firmware/ti-connectivity/wl1271-nvs.bin"
	echo -e "\t\t-cont - run TxCont command sequence. " \
"\n\t\t\tSet variable WL12XX_TUNE to provide parameters: <band> <channel>" \
"\n\t\t\tSet variable WL12XX_TXCONT to provide parameters: <delay> <rate> " \
"\n\t\t\t\t<size> <amount> <power> <seed> <pkt mode> <DC on/off> <gi> " \
"\n\t\t\t\t<preamble> <type> <scramble> <clpc> <seq nbr mode> <mac>"
	echo -e "\t\t-mac <NVS file> <MAC address> - update MAC address " \
"value in NVS file"
	echo -e "\t\t-d <value> - debuglevel, where"
	echo -e "\t\t\t  -1      - shows current value
\t\t\tDEBUG_NONE      = 0
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
\t\t\tDEBUG_AP        = BIT(17)
\t\t\tDEBUG_MASTER    = (DEBUG_ADHOC | DEBUG_AP)
\t\t\tDEBUG_ALL       = ~0"
	echo -e "\t\t-ip [device number] [IP address] - set IP address for wlan device"
	echo -e "\t\t-u - unload wireless driver"
	echo -e "\t\t-ua - unload wireless framework (mac80211)"
	echo -e "\t\t-h - get this help"
}

get_chip_id()
{
	local run_it=

	run_it=`"$path_to_calib"calibrator get hw_version $1`
	if [ "$run_it" == "" ]; then
		echo -e "Fail to get HW version for $1"
		return 1
	fi

	#echo -e "${run_it:0:4}"
	if [ "${run_it:0:4}" -eq "0503" ]; then
		chip_arch="128x"
	fi

	return 0
}

get_driver_info()
{
	local run_it=

	run_it=`"$path_to_calib"calibrator get drv_info $1`
	if [ "$run_it" == "" ]; then
		echo -e "Fail to get driver info for $1"
		return 1
	fi

	echo -e "$run_it"
}

prepare_reference_nvs_file()
{
	local ret=
	echo -e "+++ Create reference NVS with INI $path_to_ini"

	ret=`"$path_to_calib"calibrator set ref_nvs $path_to_ini`
	if [ "$ret" == "" ]; then
		echo -e "Fail to prepare reference NVS"
		return 1
	fi

	case ${ret:0:4} in
		"0503") chip_arch="128x"
			have_arch=`expr $have_arch + 1`
		;;
		"0403")
			have_arch=`expr $have_arch + 1`
		;;
		*)
		   echo -e "Unknown chip architecture"
		   return 1
		;;
	esac

	return 0
}

prepare_final_nvs_file()
{
	if [ "$chip_arch" == "127x" ]; then
		nvs_full_path=$path_to_install$nvs_127x_filename
	else
		nvs_full_path=$path_to_install$nvs_128x_filename
	fi

	rm -rf $path_to_install$nvs_link_filename

	if [ "$is_android" -eq "0" ]; then
		run_it=`cp -f ./new-nvs.bin $nvs_full_path`
	else
		run_it=`cat ./new-nvs.bin > $nvs_full_path`
	fi

	here=`pwd`
	cd $path_to_install
	if [ "$chip_arch" == "127x" ]; then
		ln -s $nvs_127x_filename $nvs_link_filename
	else
		ln -s $nvs_128x_filename $nvs_link_filename
	fi
	cd $here

	return 0
}

set_dynamic_debug()
{
	if [ ! -e /sys/module/wl12xx/parameters/debug_level ]; then
		echo -e "\nThe wl12xx not loaded"
		return 1
	fi

	if [ ! -e /sys/kernel/debug/dynamic_debug/control ]; then
		echo -e "\nMissing /sys/kernel/debug/dynamic_debug/control"
		return 1
	fi

	case "$dbg_lvl" in
		-1)
			dbg_lvl=`cat /sys/module/wl12xx/parameters/debug_level`
			echo -e "\ndbg lvl: $dbg_lvl\n"
		;;
		*)
			echo "$dbg_lvl" > /sys/module/wl12xx/parameters/debug_level
			echo 'module cfg80211 +p' > /sys/kernel/debug/dynamic_debug/control
			echo 'module mac80211 +p' > /sys/kernel/debug/dynamic_debug/control
			echo 'module wl12xx +p' > /sys/kernel/debug/dynamic_debug/control
			echo 'module wl12xx_sdio +p' > /sys/kernel/debug/dynamic_debug/control
		;;
	esac

	return 0
}

mount_debugfs()
{
	if [ "$is_android" -eq "0" ]; then
		if [ ! -e /sys/kernel/debug/tracing ]; then
			mount -t debugfs none /sys/kernel/debug/
		fi
	fi
}

# parameter - 0-unload, 1-reload, 2-load
manage_mac80211()
{
	local param=$1

	case $param in
		0) echo -e "+++ Unload mac80211 framework"
		;;
		1) echo -e "+++ Reload mac80211 framework"
		;;
		2) echo -e "+++ Load mac80211 framework"
		;;
	esac

	if [ "$is_android" -eq "0" ]; then
		depmod -a
		if [ "$param" -lt "2" ]; then
			modprobe -r mac80211
		fi
		if [ "$param" -gt "0" ]; then
			modprobe mac80211
			if [ "$?" != "0" ]; then
				echo -e "Fail to load mac80211"
				return 1
			fi
		fi
	else
		if [ "$param" -lt "2" ]; then
			run_it=`cat /proc/modules | grep "mac80211"`
			if [ "$run_it" != "" ]; then
				"$rmmod_path"rmmod mac80211
			fi
			run_it=`cat /proc/modules | grep "cfg80211"`
			if [ "$run_it" != "" ]; then
				"$rmmod_path"rmmod cfg80211
			fi
			run_it=`cat /proc/modules | grep "compat"`
			if [ "$run_it" != "" ]; then
				"$rmmod_path"rmmod compat
			fi
		fi
		if [ "$param" -gt "1" ]; then
			run_it=`cat /proc/modules | grep "compat"`
			if [ "$run_it" == "" ]; then
				"$insmode_path"insmod /system/lib/modules/compat.ko
			fi
			run_it=`cat /proc/modules | grep "cfg80211"`
			if [ "$run_it" == "" ]; then
				"$insmode_path"insmod /system/lib/modules/cfg80211.ko
			fi
			run_it=`cat /proc/modules | grep "mac80211"`
			if [ "$run_it" == "" ]; then
				"$insmode_path"insmod /system/lib/modules/mac80211.ko
			fi
		fi
	fi

	return 0
}

load_wl12xx_driver()
{
	echo -e "+++ Load wl12xx driver"

	if [ "$is_android" -eq "0" ]; then
		depmod -a
		modprobe wl12xx_sdio
	else
		run_it=`cat /proc/modules | grep "wl12xx"`
		if [ "$run_it" == "" ]; then
			"$insmode_path"insmod /system/lib/modules/wl12xx.ko
		fi

		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx"
			return 1
		fi

		run_it=`cat /proc/modules | grep "wl12xx_sdio"`
		if [ "$run_it" == "" ]; then
			"$insmode_path"insmod /system/lib/modules/wl12xx_sdio.ko
		fi

		if [ "$?" != "0" ]; then
			echo -e "Fail to load wl12xx_sdio"
			return 1
		fi
	fi

	sleep 1
	if [ -e /sys/kernel/debug/tracing ]; then
		echo 1 > /sys/kernel/debug/tracing/events/mac80211/enable
	fi

	return 0
}

# get parameter number of modules to remove
# 2 - both wl12xx_sdio and wl12xx
# 1 - only wl12xx_sdio
unload_wl12xx_driver()
{
	local nbr_of_modules=2

	echo -e "+++ Unload wl12xx driver"

	if [ "$#" -eq "1" ]; then
		nbr_of_modules=$1
	fi

	if [ "$interactive" -eq "1" ]; then
		echo -e "\n\tRemove wl12xx_sdio"
	fi
	run_it=`cat /proc/modules | grep "wl12xx_sdio"`
	if [ "$run_it" != "" ]; then
		"$rmmod_path"rmmod wl12xx_sdio
	fi

	if [ "$nbr_of_modules" -eq "2" ]; then

		if [ "$interactive" -eq "1" ]; then
			echo -e "\n\tRemove wl12xx"
		fi
		run_it=`cat /proc/modules | grep "wl12xx"`
		if [ "$run_it" != "" ]; then
			"$rmmod_path"rmmod wl12xx
		fi
	fi

	return 0
}

cmd_power_mode()
{
	"$path_to_calib"calibrator wlan0 plt power_mode $1
	if [ "$?" != "0" ]; then
		echo -e "Fail to set power mode to $1"
		return 1
	fi

	return 0
}

# get parameters: band, channel
cmd_tune_channel()
{
	local params=$*

	if [ "$WL12XX_TUNE" ]; then
		params=$WL12XX_TUNE
	fi

	if [ "$params" ]; then
		"$path_to_calib"calibrator wlan0 plt tune_channel $params
		if [ "$?" != "0" ]; then
			echo -e "Fail to tune channel"
			return 1
		fi
	else
		echo -e "Missing input parameters"
		return 1
	fi

	return 0
}

cmd_nvs_ver()
{
	"$path_to_calib"calibrator phy0 plt nvs_ver wlan0
	if [ "$?" != "0" ]; then
		echo -e "Command nvs version failed"
		return 1
	fi

	return 0
}

cmd_tx_bip()
{
	run_it=`cat $path_to_ini | grep "RxTraceInsertionLoss_5G"`
	if [ "$run_it" != "" ]; then
		"$path_to_calib"calibrator wlan0 plt tx_bip 1 1 1 1 1 1 1 1 $nvs_full_path
		if [ "$?" != "0" ]; then
			echo -e "Fail to calibrate"
			return 1
		fi
	else
		"$path_to_calib"calibrator wlan0 plt tx_bip 1 0 0 0 0 0 0 0 $nvs_full_path
		if [ "$?" != "0" ]; then
			echo -e "Fail to calibrate"
			return 1
		fi
	fi

	return 0
}

cmd_tx_stop()
{
	"$path_to_calib"calibrator wlan0 plt tx_stop
	if [ "$?" != "0" ]; then
		echo -e "Fail to stop"
		return 1
	fi

	return 0
}

cmd_tx_cont()
{
	local params=$WL12XX_TXCONT

	if [ "$WL12XX_TXCONT" ]; then
		"$path_to_calib"calibrator wlan0 plt tx_cont $params
		if [ "$?" != "0" ]; then
			echo -e "Fail to run tx_cont"
			return 1
		fi
	else
		echo -e "Missing variable WL12XX_TXCONT"
		return 1
	fi

	return 0
}

# parameters
#    path to NVS file where to set MAC address
#    MAC address
cmd_set_mac_address()
{
	if [ "$interactive" -eq "1" ]; then
		echo -e "Going to set MAC address $mac_addr"
	fi

	"$path_to_calib"calibrator set nvs_mac $1 $2
	if [ "$?" != "0" ]; then
		echo -e "Fail to set NVS MAC address"
		return 1
	fi

	return 0
}

android_start_gui()
{
	if [ "$is_android" -eq "1" ]; then
		start
		sleep 2
	fi
}

android_stop_gui()
{
	if [ "$is_android" -eq "1" ]; then
		stop
		sleep 2
	fi
}

i=0
nbr_args=$#
bootlevel=0
dbg_lvl=0
ref_clk=0
mac_addr="08:00:28:90:64:31"
set_mac_addr=0
wlan_dev="0"
ip_addr="192.168.1.1"
set_ip_addr=0
have_path_to_ini=0
path_to_ini=""
path_to_ini2=""
have_path_to_install=0
path_to_install="/lib/firmware/ti-connectivity/"
is_android=0
path_to_calib="./"
interactive=0
insmod_path=
rmmod_path=
support_nvs20=0
nvs_link_filename="wl12xx-nvs.bin"
nvs_127x_filename="wl127x-nvs.bin"
nvs_128x_filename="wl128x-nvs.bin"
nvs_full_path=
chip_arch="127x"
have_arch=0

if [ $ANDROID_ROOT ]; then
	is_android=`expr $is_android + 1`
	prefix_path2modules="/system/"
	insmod_path="/system/bin/"
	rmmod_path="/system/bin/"
	path_to_calib=""
	path_to_install="/system/etc/firmware/ti-connectivity/"
fi

while [ "$i" -lt "$nbr_args" ]
do
	case $1 in
		-b)
			bootlevel=$2
			nbr_args=`expr $nbr_args - 1`
			shift
		;;
		-c)
			if [ "$nbr_args" -lt "2" ]; then
				echo -e "missing arguments"
				exit 1
			fi

			bootlevel=64
			have_path_to_ini=`expr $have_path_to_ini + 1`
			path_to_ini=$2
			if [ "$nbr_args" -eq "2" ]; then
				nbr_args=`expr $nbr_args - 1`
				shift
				break
			fi
			mac_addr=$3
			nbr_args=`expr $nbr_args - 2`
			shift
			shift
		;;
		-c2)    # calibration with 2 FEMs
			if [ "$nbr_args" -lt "3" ]; then
				echo -e "missing arguments"
				exit 1
			fi

			bootlevel=32
			have_path_to_ini=`expr $have_path_to_ini + 1`
			path_to_ini=$2
			path_to_ini2=$3
			if [ "$nbr_args" -eq "3" ]; then
				nbr_args=`expr $nbr_args - 2`
				shift
				shift
				break
			fi
			mac_addr=$4
			nbr_args=`expr $nbr_args - 3`
			shift
			shift
			shift
		;;
		-cont)  # running TxCont procedure
			interactive=`expr $interactive + 1`
			bootlevel=16
			shift
		;;
		-d)
			interactive=`expr $interactive + 1`
			dbg_lvl=$2
			nbr_args=`expr $nbr_args - 1`
			shift
			set_dynamic_debug
			exit 0
		;;
		-mac)
			if [ "$nbr_args" -lt "3" ]; then
				echo -e "missing arguments"
				exit 1
			fi
			interactive=`expr $interactive + 1`
			have_path_to_install=`expr $have_path_to_install + 1`
			path_to_install=$2
			mac_addr=$3
			set_mac_addr=`expr $set_mac_addr + 1`
			nbr_args=`expr $nbr_args - 2`
			shift
		;;
		-nvs20)
			support_nvs20=`expr $support_nvs20 + 1`
			shift
		;;
		-ip)
			if [ "$nbr_args" -lt "3" ]; then
				echo -e "missing arguments"
				exit 1
			fi
			interactive=`expr $interactive + 1`
			set_ip_addr=`expr $set_ip_addr + 1`
			case $2 in
				"") echo -e "using default ip address"
				;;
				-*) echo -e "this is another option"
				;;
				*)
				wlan_dev=$2
				ip_addr=$3
				nbr_args=`expr $nbr_args - 2`
				shift
				;;
			esac
			shift
		;;
		-ini)
			have_path_to_ini=`expr $have_path_to_ini + 1`
			path_to_ini=$2
			nbr_args=`expr $nbr_args - 1`
			shift
		;;
		-info)
			dev_name="wlan0"
			if [ "$nbr_args" -eq "2" ]; then
				nbr_args=`expr $nbr_args - 1`
				dev_name=$2
				shift
			fi
			interactive=`expr $interactive + 1`
			get_driver_info $dev_name
			shift
		;;
		-tune)
			interactive=`expr $interactive + 1`
			cmd_tune_channel
			if [ "$?" != "0" ]; then
				exit 1
			fi
			shift
		;;
		-u)
			interactive=`expr $interactive + 1`
			unload_wl12xx_driver
			shift
		;;
		-ua)
			interactive=`expr $interactive + 1`
			unload_wl12xx_driver
			manage_mac80211 0
			shift
		;;
		-arch)
			dev_name="wlan0"
			if [ "$nbr_args" -eq "2" ]; then
				nbr_args=`expr $nbr_args - 1`
				dev_name=$2
				shift
			fi
			interactive=`expr $interactive + 1`
			get_chip_id $dev_name
			shift
		;;
		-h)
			interactive=`expr $interactive + 1`
			usage
			exit 0
		;;
		*) echo -e "\tNothing to do"
		;;
	esac
	i=`expr $i + 1`
	shift
done

stage_uno=0
stage_due=0
stage_quattro=0
stage_otto=0
stage_sedici=0
stage_trentadue=0
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
	32) stage_trentadue=`expr $stage_trentadue + 1`
	;;
	34)
	    stage_due=`expr $stage_due + 1`
	    stage_trentadue=`expr $stage_trentadue + 1`
	;;
	64) stage_sessanta_quattro=`expr $stage_sessanta_quattro + 1`
	;;
	66)
	    stage_due=`expr $stage_due + 1`
	    stage_sessanta_quattro=`expr $stage_sessanta_quattro + 1`
	;;
esac

	if [ "$interactive" -eq "0" ]; then
		echo -e "\t------------         ------------\n"
		echo -e "\t---===<<<((( WELCOME )))>>>===---\n"
		echo -e "\t------------         ------------\n"
	fi

if [ "$stage_uno" -ne "0" ]; then
	echo -e "+++ Mount the debugfs on /sys/kernel/debug"

	echo 8 > /proc/sys/kernel/printk

	if [ -e /libexec/inetd ]; then
		/libexec/inetd /etc/inetd.conf &
	fi

	mount_debugfs
fi

if [ "$stage_due" -ne "0" ]; then
	manage_mac80211 1
fi

if [ "$stage_quattro" -ne "0" ]; then
	load_wl12xx_driver
	if [ "$?" != "0" ]; then
		exit 1
	fi
fi

if [ "$stage_otto" -ne "0" ]; then
	echo -e "+++ Start interface, enable monitoring events, run wpa_supplicant"

	ifconfig wlan0 up
	if [ "$?" != "0" ]; then
		echo -e "Fail to start iface"
		exit 1
	fi

	wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -Dnl80211 &
fi

if [ "$stage_sedici" -ne "0" ]; then

	android_stop_gui

	load_wl12xx_driver
	if [ "$?" != "0" ]; then
		exit 1
	fi

	cmd_power_mode on
	if [ "$?" != "0" ]; then
		exit 1
	fi

	# gets parameter from environment variable WL12XX_TUNE
	cmd_tune_channel
	if [ "$?" != "0" ]; then
		cmd_power_mode off
		exit 1
	fi

	# gets parameter from environment variable WL12XX_TXCONT
	cmd_tx_cont

	cmd_tx_stop

	cmd_power_mode off
	if [ "$?" != "0" ]; then
		exit 1
	fi

	android_start_gui
fi

if [ "$stage_trentadue" -ne "0" ]; then

	if [ "$have_path_to_ini" -eq "0" ]; then
		echo -e "Missing ini file parameter"
		exit 1
	fi

	android_stop_gui

	# 1. unload wl12xx kernel modules
	unload_wl12xx_driver
	manage_mac80211 1

	# 2. create reference NVS file with default MAC
	echo -e "+++ Create reference NVS with $path_to_ini $path_to_ini2"
	"$path_to_calib"calibrator set ref_nvs2 $path_to_ini $path_to_ini2
	if [ "$?" != "0" ]; then
		echo -e "Fail to ..."
		exit 1
	fi

	# 3. Set AutoFEM detection to auto
	echo -e "+++ Set Auto FEM detection to auto"
	"$path_to_calib"calibrator set autofem 1 ./new-nvs.bin
	if [ "$?" != "0" ]; then
		echo -e "Fail to set auto"
		exit 1
	fi

	# 4. copy NVS to proper place
	echo -e "+++ Copy reference NVS file to $path_to_install"
	prepare_final_nvs_file

	# 5. load wl12xx kernel modules
	load_wl12xx_driver

	# 6. calibrate
	echo -e "+++ Calibrate"
	cmd_power_mode on
	if [ "$?" != "0" ]; then
		exit 1
	fi

	cmd_tune_channel 0 7
	if [ "$?" != "0" ]; then
		cmd_power_mode off
		exit 1
	fi

	if [ "$support_nvs20" -eq "0" ]; then
		cmd_nvs_ver
		if [ "$?" != "0" ]; then
			cmd_power_mode off
			exit 1
		fi
	fi

	cmd_tx_bip
	if [ "$?" != "0" ]; then
		cmd_power_mode off
		exit 1
	fi

	cmd_power_mode off
	if [ "$?" != "0" ]; then
		exit 1
	fi

	# 7. unload wl12xx kernel modules
	unload_wl12xx_driver

	# 8. update MAC address in the NVS file
	echo -e "+++ Update MAC address in the NVS file"
	cmd_set_mac_address ./new-nvs.bin $mac_addr
	if [ "$?" != "0" ]; then
		exit 1
	fi

	# 9. copy calibrated NVS file to proper place
	echo -e "+++ Copy calibrated NVS file to $path_to_install"
	prepare_final_nvs_file

	# 10. load wl12xx kernel modules
	manage_mac80211 1
	load_wl12xx_driver

	mount_debugfs

	echo -e "\n\tDear Customer, you are  ready  to "
	echo -e "\t\tuse our calibrated  device\n"

	android_start_gui
fi

if [ "$stage_sessanta_quattro" -ne "0" ]; then

	if [ "$have_path_to_ini" -eq "0" ]; then
		echo -e "Missing ini file parameter"
		exit 1
	fi

	# Stop GUI if run under Android
	android_stop_gui

	# To insure mac80211 is loaded
	manage_mac80211 2

	# Create reference NVS file with default MAC
	prepare_reference_nvs_file
	if [ "$?" != "0" ]; then
		exit 1
	fi

	# Copy NVS to proper place
	prepare_final_nvs_file
	if [ "$?" != "0" ]; then
		echo -e "Fail to prepare reference NVS file"
		exit 1
	else
		echo -e "+++ Copy reference NVS file to $path_to_install"
	fi

	unload_wl12xx_driver

	# Reload mac80211 insures name phy0
	manage_mac80211 1

	load_wl12xx_driver
	if [ "$?" != "0" ]; then
		exit 1
	fi

	cmd_power_mode on
	if [ "$?" != "0" ]; then
		exit 1
	fi

	cmd_tune_channel 0 7
	if [ "$?" != "0" ]; then
		cmd_power_mode off
		exit 1
	fi

	if [ "$support_nvs20" -eq "0" ]; then
		cmd_nvs_ver
		if [ "$?" != "0" ]; then
			cmd_power_mode off
			exit 1
		fi
	fi

	cmd_tx_bip
	if [ "$?" != "0" ]; then
		cmd_power_mode off
		exit 1
	fi

	cmd_power_mode off
	if [ "$?" != "0" ]; then
		exit 1
	fi

	unload_wl12xx_driver

	# Update MAC address in the NVS file
	echo -e "+++ Update MAC address in the NVS file"
	cmd_set_mac_address ./new-nvs.bin $mac_addr
	if [ "$?" != "0" ]; then
		exit 1
	fi

	# Copy calibrated NVS file to proper place
	prepare_final_nvs_file
	if [ "$?" != "0" ]; then
		echo -e "Fail to prepare calibrated NVS file"
		exit 1
	else
		echo -e "+++ Copy calibrated NVS file to $path_to_install"
	fi

	# Load wl12xx kernel modules
	manage_mac80211 1
	load_wl12xx_driver

	mount_debugfs

	echo -e "\n\tDear Customer, you are  ready  to "
	echo -e "\t\tuse our calibrated  device\n"

	android_start_gui
fi

if [ "$set_ip_addr" -ne "0" ]; then
	echo -e "Going to set IP $ip_addr"
	ifconfig wlan$wlan_dev $ip_addr up
fi

if [ "$set_mac_addr" -ne "0" ]; then
	cmd_set_mac_address $path_to_install $mac_addr
	if [ "$?" != "0" ]; then
		exit 1
	fi
fi

exit 0
