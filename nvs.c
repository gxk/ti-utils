/*
 * PLT utility for wireless chip supported by TI's driver wl12xx
 *
 * See README and COPYING for more details.
 */

#include <sys/ioctl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>

#include <netlink/genl/genl.h>
#include <netlink/genl/family.h>
#include <netlink/genl/ctrl.h>
#include <netlink/msg.h>
#include <netlink/attr.h>
#include <linux/wireless.h>
#include "nl80211.h"

#include "calibrator.h"
#include "plt.h"
#include "ini.h"

/* 2048 - it should be enough for any chip, until... 22dec2010 */
#define BUF_SIZE_4_NVS_FILE	2048

static const char if_name_fmt[] = "wlan%d";

int get_mac_addr(int ifc_num, unsigned char *mac_addr)
{
	int s;
	struct ifreq ifr;
#if 0
	if (ifc_num < 0 || ifc_num >= ETH_DEV_MAX)
		return 1;
#endif
	s = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);
	if (s < 0) {
		printf("unable to socket (%s)\n", strerror(errno));
		return 1;
	}

	memset(&ifr, 0, sizeof(struct ifreq));
	sprintf(ifr.ifr_name, if_name_fmt, ifc_num) ;
	if (ioctl(s, SIOCGIFHWADDR, &ifr) < 0) {
		printf("unable to ioctl (%s)\n", strerror(errno));
		close(s);
		return 1;
	}

	close(s);

	memcpy(mac_addr, &ifr.ifr_ifru.ifru_hwaddr.sa_data[0], 6);

	return 0;
}

int file_exist(const char *filename)
{
	struct stat buf;
	int ret;

	if (filename == NULL) {
		printf("wrong parameter\n");
		return -1;
	}

	ret = stat(filename, &buf);
	if (ret != 0) {
		printf("fail to stat (%s)\n", strerror(errno));
		return -1;
	}

	return (int)buf.st_size;
}

static int read_from_current_nvs(const unsigned char *nvs_file,
	char *buf, int size)
{
	int curr_nvs;
	int fl_sz = file_exist(CURRENT_NVS_NAME);

	if (nvs_file == NULL)
		fl_sz = file_exist(CURRENT_NVS_NAME);
	else
		fl_sz = file_exist(nvs_file);

	if (fl_sz < 0) {
		printf("File %s not exists\n", CURRENT_NVS_NAME);
		return 1;
	}

	curr_nvs = open(CURRENT_NVS_NAME, O_RDONLY, S_IRUSR | S_IWUSR);
	if (curr_nvs < 0) {
		printf("%s> Unable to open NVS file for reference (%s)\n",
			__func__, strerror(errno));
		return 1;
	}

	read(curr_nvs, buf, size);

	close(curr_nvs);

	return 0;
}

static int fill_nvs_def_rx_params(int fd)
{
	unsigned char type = eNVS_RADIO_RX_PARAMETERS;
	unsigned short length = NVS_RX_PARAM_LENGTH;
	int i;

	/* Rx type */
	write(fd, &type, 1);

	/* Rx length */
	write(fd, &length, 2);

	type = DEFAULT_EFUSE_VALUE; /* just reuse of var */
	for (i = 0; i < NVS_RX_PARAM_LENGTH; i++)
		write(fd, &type, 1);

	return 0;
}

static void nvs_parse_data(const unsigned char *buf,
	struct wl1271_cmd_cal_p2g *pdata, unsigned int *pver)
{
#define BUFFER_INDEX    (buf_idx + START_PARAM_INDEX + info_idx)
	unsigned short buf_idx;
	unsigned char tlv_type;
	unsigned short tlv_len;
	unsigned short info_idx;
	unsigned int nvsTypeInfo;
	unsigned char nvs_ver_oct_idx;
	unsigned char shift;

	for (buf_idx = 0; buf_idx < NVS_TOTAL_LENGTH;) {
		tlv_type = buf[buf_idx];

		/* fill the correct mode to fill the NVS struct buffer */
		/* if the tlv_type is the last type break from the loop */
		switch (tlv_type) {
		case eNVS_RADIO_TX_PARAMETERS:
			nvsTypeInfo = eNVS_RADIO_TX_TYPE_PARAMETERS_INFO;
			break;
		case eNVS_RADIO_RX_PARAMETERS:
			nvsTypeInfo = eNVS_RADIO_RX_TYPE_PARAMETERS_INFO;
			break;
		case eNVS_VERSION:
			for (*pver = 0, nvs_ver_oct_idx = 0;
				nvs_ver_oct_idx < NVS_VERSION_PARAMETER_LENGTH;
				nvs_ver_oct_idx++) {
				shift = 8 * (NVS_VERSION_PARAMETER_LENGTH -
					1 - nvs_ver_oct_idx);
				*pver += ((buf[buf_idx + START_PARAM_INDEX +
					nvs_ver_oct_idx]) << shift);
			}
			break;
		case eTLV_LAST:
		default:
			return;
		}

		tlv_len = (buf[buf_idx + START_LENGTH_INDEX  + 1] << 8) +
			buf[buf_idx + START_LENGTH_INDEX];

		/* if TLV type is not NVS ver fill the NVS according */
		/* to the mode TX/RX */
		if ((eNVS_RADIO_TX_PARAMETERS == tlv_type) ||
			(eNVS_RADIO_RX_PARAMETERS == tlv_type)) {
			pdata[nvsTypeInfo].type = tlv_type;
			pdata[nvsTypeInfo].len = tlv_len;

			for (info_idx = 0; (info_idx < tlv_len) &&
				(BUFFER_INDEX < NVS_TOTAL_LENGTH);
					info_idx++) {
				pdata[nvsTypeInfo].buf[info_idx] =
					buf[BUFFER_INDEX];
			}
		}

		/* increment to the next TLV */
		buf_idx += START_PARAM_INDEX + tlv_len;
	}
}

static int nvs_fill_old_rx_data(int fd, const unsigned char *buf,
	unsigned short len)
{
	unsigned short idx;
	unsigned char rx_type;

	/* RX BiP type */
	rx_type = eNVS_RADIO_RX_PARAMETERS;
	write(fd, &rx_type, 1);

	/* RX BIP Length */
	write(fd, &len, 2);

	for (idx = 0; idx < len; idx++)
		write(fd, &(buf[idx]), 1);

	return 0;
}

static int nvs_fill_nvs_part(int fd, char *buf)
{
	unsigned char *p = buf;

	write(fd, p, 0x1D4);

	return 0;
}

static int nvs_fill_radio_params(int fd, struct wl12xx_ini *ini, char *buf)
{
	int size;
	struct wl1271_ini *gp = &ini->ini1271;

	size  = sizeof(struct wl1271_ini);
	printf("Radio prms sz: %d\n", size);

	if (ini) {	/* for reference NVS */
		unsigned char *c = (unsigned char *)gp;
		int i;

		for (i = 0; i < size; i++)
			write(fd, c++, 1);
	} else {
		unsigned char *p = buf + 0x1D4;
		write(fd, p, size);
	}

	return 0;
}

static int nvs_fill_radio_params_128x(int fd, struct wl12xx_ini *ini, char *buf)
{
	int size;
	struct wl128x_ini *gp = &ini->ini128x;

	size  = sizeof(struct wl128x_ini);
	printf("Radio prms sz: %d\n", size);

	if (ini) {	/* for reference NVS */
		unsigned char *c = (unsigned char *)gp;
		int i;

		for (i = 0; i < size; i++)
			write(fd, c++, 1);
	printf("written sz: %d\n", i);
	} else {
		unsigned char *p = buf + 0x1D4;
		write(fd, p, size);
	}

	return 0;
}

static int nvs_fill_version(int fd, struct wl1271_cmd_cal_p2g *pdata)
{
	unsigned char tmp = eNVS_VERSION;
	unsigned short tmp2 = NVS_VERSION_PARAMETER_LENGTH;

	write(fd, &tmp, 1);

	write(fd, &tmp2, 2);

	tmp = (pdata->ver >> 16) & 0xff;
	write(fd, &tmp, 1);

	tmp = (pdata->ver >> 8) & 0xff;
	write(fd, &tmp, 1);

	tmp = pdata->ver & 0xff;
	write(fd, &tmp, 1);

	return 0;
}

static struct wl12xx_nvs_ops wl1271_nvs_ops = {
	.nvs_fill_radio_prms = nvs_fill_radio_params,
};

static struct wl12xx_nvs_ops wl128x_nvs_ops = {
	.nvs_fill_radio_prms = nvs_fill_radio_params_128x,
};

int prepare_nvs_file(void *arg, struct wl12xx_common *cmn)
{
	int new_nvs, i;
	unsigned char mac_addr[MAC_ADDR_LEN];
	struct wl1271_cmd_cal_p2g *pdata;
	struct wl1271_cmd_cal_p2g old_data[eNUMBER_RADIO_TYPE_PARAMETERS_INFO];
	unsigned char buf[2048];
	unsigned char *p;
	struct wl12xx_ini *pini = NULL;
	const unsigned char vals[] = {
		0x0, 0x1, 0x6d, 0x54, 0x71, eTLV_LAST, eNVS_RADIO_TX_PARAMETERS
	};

	if (arg == NULL) {
		printf("%s> Missing args\n", __func__);
		return 1;
	}

	/* create new NVS file */
	new_nvs = open(NEW_NVS_NAME,
		O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
	if (new_nvs < 0) {
		printf("%s> Unable to open new NVS file\n", __func__);
		return 1;
	}

	write(new_nvs, &vals[1], 1);
	write(new_nvs, &vals[2], 1);
	write(new_nvs, &vals[3], 1);

	if (get_mac_addr(0, mac_addr)) {
		printf("%s> Fail to get mac addr\n", __func__);
		close(new_nvs);
		return 1;
	}

	/* write down MAC address in new NVS file */
	write(new_nvs, &mac_addr[5], 1);
	write(new_nvs, &mac_addr[4], 1);
	write(new_nvs, &mac_addr[3], 1);
	write(new_nvs, &mac_addr[2], 1);

	write(new_nvs, &vals[1], 1);
	write(new_nvs, &vals[4], 1);
	write(new_nvs, &vals[3], 1);

	write(new_nvs, &mac_addr[1], 1);
	write(new_nvs, &mac_addr[0], 1);

	write(new_nvs, &vals[0], 1);
	write(new_nvs, &vals[0], 1);

	/* fill end burst transaction zeros */
	for (i = 0; i < NVS_END_BURST_TRANSACTION_LENGTH; i++)
		write(new_nvs, &vals[0], 1);

	/* fill zeros to Align TLV start address */
	for (i = 0; i < NVS_ALING_TLV_START_ADDRESS_LENGTH; i++)
		write(new_nvs, &vals[0], 1);

	/* Fill TxBip */
	pdata = (struct wl1271_cmd_cal_p2g *)arg;

	write(new_nvs, &vals[6], 1);
	write(new_nvs, &pdata->len, 2);

	p = (unsigned char *)&(pdata->buf);
	for (i = 0; i < pdata->len; i++)
		write(new_nvs, p++, 1);

	/* must to return, because anyway need
	 * the radio parameters from old NVS */
	if (read_from_current_nvs(NULL, buf, BUF_SIZE_4_NVS_FILE)) {
		close(new_nvs);
		return 1;
	}

	if (cmn) {
		fill_nvs_def_rx_params(new_nvs);

		pini = &cmn->ini;
	} else {
		unsigned int old_ver;
#if 0
		{
			unsigned char *p = (unsigned char *)buf;
			for (old_ver = 0; old_ver < 1024; old_ver++) {
				if (old_ver%16 == 0)
					printf("\n");
				printf("%02x ", *p++);
			}
		}
#endif
		memset(old_data, 0,
			sizeof(struct wl1271_cmd_cal_p2g)*
				eNUMBER_RADIO_TYPE_PARAMETERS_INFO);
		nvs_parse_data(&buf[NVS_PRE_PARAMETERS_LENGTH],
			old_data, &old_ver);

		nvs_fill_old_rx_data(new_nvs,
			old_data[eNVS_RADIO_RX_TYPE_PARAMETERS_INFO].buf,
			old_data[eNVS_RADIO_RX_TYPE_PARAMETERS_INFO].len);
	}

	/* fill NVS version */
	if (nvs_fill_version(new_nvs, pdata))
		printf("Fail to fill version\n");

	/* fill end of NVS */
	write(new_nvs, &vals[5], 1); /* eTLV_LAST */
	write(new_nvs, &vals[5], 1); /* eTLV_LAST */
	write(new_nvs, &vals[0], 1);
	write(new_nvs, &vals[0], 1);

	/* fill radio params */
	if (cmn->nvs_ops->nvs_fill_radio_prms(new_nvs, pini, buf))
		printf("Fail to fill radio params\n");

	close(new_nvs);

	return 0;
}

int update_nvs_file(const char *nvs_file, struct wl12xx_common *cmn)
{
	int new_nvs, res = 0;
	unsigned char buf[2048];
	unsigned char *p;

	if (nvs_file == NULL)
		printf("The path to current NVS file not provided."
			"Will use default (%s)\n", CURRENT_NVS_NAME);

	if (read_from_current_nvs(nvs_file, buf, BUF_SIZE_4_NVS_FILE))
		return 1;

	/* create new NVS file */
	new_nvs = open(NEW_NVS_NAME,
		O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
	if (new_nvs < 0) {
		fprintf(stderr, "%s> Unable to open new NVS file\n", __func__);
		return 1;
	}

	/* fill nvs part */
	if (nvs_fill_nvs_part(new_nvs, buf)) {
		fprintf(stderr, "Fail to fill NVS part\n");
		res = 1;

		goto out;
	}

	/* fill radio params */
	if (cmn->nvs_ops->nvs_fill_radio_prms(new_nvs, &cmn->ini, buf)) {
		printf("Fail to fill radio params\n");
		res = 1;
	}

out:
	close(new_nvs);

	return res;
}

void cfg_nvs_ops(struct wl12xx_common *cmn)
{
	if (cmn->arch == WL1271_ARCH)
		cmn->nvs_ops = &wl1271_nvs_ops;
	else
		cmn->nvs_ops = &wl128x_nvs_ops;
}
