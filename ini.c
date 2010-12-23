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

static char *ini_get_line(char *s, int size, FILE *stream, int *line,
				  char **_pos)
{
	char *pos, *end, *sstart;

	while (fgets(s, size, stream)) {
		s[size - 1] = '\0';
		pos = s;

		/* Skip white space from the beginning of line. */
		while (*pos == ' ' || *pos == '\t' || *pos == '\r')
			pos++;

		/* Skip comment lines and empty lines */
		if (*pos == '#' || *pos == '\n' || *pos == '\0')
			continue;

		/*
		 * Remove # comments unless they are within a double quoted
		 * string.
		 */
		sstart = strchr(pos, '"');
		if (sstart)
			sstart = strrchr(sstart + 1, '"');
		if (!sstart)
			sstart = pos;
		end = strchr(sstart, '#');
		if (end)
			*end-- = '\0';
		else
			end = pos + strlen(pos) - 1;

		/* Remove trailing white space. */
		while (end > pos &&
		       (*end == '\n' || *end == ' ' || *end == '\t' ||
			*end == '\r'))
			*end-- = '\0';

		if (*pos == '\0')
			continue;

		(*line)++;

		if (_pos)
			*_pos = pos;
		return pos;
	}

	if (_pos)
		*_pos = NULL;

	return NULL;
}

static int split_line(char *line, char **name, char **value)
{
	char *pos = line;

	*value = strchr(pos, '=');
	if (!*value) {
		fprintf(stderr, "Wrong format of line\n");
		return 1;
	}

	*name = *value;

	(*name)--;
	while (**name == ' ' || **name == '\t' || **name == '\r')
		(*name)--;

	*++(*name) = '\0';

	(*value)++;
	while (**value == ' ' || **value == '\t' || **value == '\r')
		(*value)++;

	return 0;
}

#define COMPARE_N_ADD(temp, str, val, ptr, size)		\
	if (strncmp(temp, str, sizeof(temp)) == 0) {		\
		int i;						\
		unsigned char *p = ptr;				\
		for (i = 0; i < size; i++) {			\
			*p = strtol(val, NULL, 16);		\
			if (i != sizeof(ptr)-1) {		\
				val += 3; p++;			\
			}					\
		}						\
		return 0;					\
	}

#define DBG_COMPARE_N_ADD(temp, str, val, ptr, size)		\
	if (strncmp(temp, str, sizeof(temp)) == 0) {		\
		int i;						\
		unsigned char *p = ptr;				\
		for (i = 0; i < size; i++) {			\
			*p = strtol(val, NULL, 16);		\
			if (i != sizeof(ptr)-1) {		\
				val += 3; p++;			\
			}					\
		}						\
		p = ptr;					\
		printf("%s ", temp);				\
		for (i = 0; i < size; i++) {			\
			printf("%02X ", *p);			\
			p++;					\
		}						\
		printf("\n");					\
		return 0;					\
	}

#define COMPARE_N_ADD2(temp, str, val, ptr, size)		\
	if (strncmp(temp, str, sizeof(temp)) == 0) {		\
		int i;						\
		unsigned short *p = ptr;				\
		for (i = 0; i < size; i++) {			\
			*p = strtol(val, NULL, 16);		\
			if (i != sizeof(ptr)-1) {		\
				val += 5; p++;			\
			}					\
		}						\
		return 0;					\
	}

#define DBG_COMPARE_N_ADD2(temp, str, val, ptr, size)		\
	if (strncmp(temp, str, sizeof(temp)) == 0) {		\
		int i;						\
		unsigned short *p = ptr;			\
		for (i = 0; i < size; i++) {			\
			*p = strtol(val, NULL, 16);		\
			if (i != sizeof(ptr)-1) {		\
				val += 5; p++;			\
			}					\
		}						\
		p = ptr;					\
		printf("%s ", temp);				\
		for (i = 0; i < size; i++) {			\
			printf("%04X ", *p);			\
			p++;					\
		}						\
		printf("\n");					\
		return 0;					\
	}

static int parse_general_prms(char *l,
	struct wl1271_ini_general_params *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD("TXBiPFEMAutoDetect", l, val,
		&gp->tx_bip_fem_auto_detect, 1);

	COMPARE_N_ADD("TXBiPFEMManufacturer", l, val,
		&gp->tx_bip_fem_manufacturer, 1);

	COMPARE_N_ADD("RefClk", l, val, &gp->ref_clock, 1);

	COMPARE_N_ADD("SettlingTime", l, val, &gp->settling_time, 1);

	COMPARE_N_ADD("ClockValidOnWakeup", l, val,
		&gp->clk_valid_on_wakeup, 1);

	COMPARE_N_ADD("DC2DCMode", l, val, &gp->dc2dc_mode, 1);

	COMPARE_N_ADD("Single_Dual_Band_Solution", l, val,
		&gp->dual_mode_select, 1);

	COMPARE_N_ADD("Settings", l, val, &gp->general_settings, 1);

	COMPARE_N_ADD("SRState", l, val, &gp->sr_state, 1);

	COMPARE_N_ADD("SRF1", l, val,
		gp->srf1, WL1271_INI_MAX_SMART_REFLEX_PARAM);

	COMPARE_N_ADD("SRF2", l, val,
		gp->srf2, WL1271_INI_MAX_SMART_REFLEX_PARAM);

	COMPARE_N_ADD("SRF3", l, val,
		gp->srf3, WL1271_INI_MAX_SMART_REFLEX_PARAM);

	return 1;
}

static int parse_band2_prms(char *l,
	struct wl1271_ini_band_params_2 *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD("RxTraceInsertionLoss_2_4G", l, val,
		&gp->rx_trace_insertion_loss, 1);

	COMPARE_N_ADD("TXTraceLoss_2_4G", l, val,
		&gp->tx_trace_loss, 1);

	COMPARE_N_ADD("RxRssiAndProcessCompensation_2_4G", l, val,
		gp->rx_rssi_process_compens,
		WL1271_INI_RSSI_PROCESS_COMPENS_SIZE);

	return 1;
}

static int parse_band5_prms(char *l,
	struct wl1271_ini_band_params_5 *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD("RxTraceInsertionLoss_5G", l, val,
		gp->rx_trace_insertion_loss, 7);

	COMPARE_N_ADD("TXTraceLoss_5G", l, val,
		gp->tx_trace_loss, 7);

	COMPARE_N_ADD("RxRssiAndProcessCompensation_5G", l, val,
		gp->rx_rssi_process_compens,
		WL1271_INI_RSSI_PROCESS_COMPENS_SIZE);

	return 1;
}

static int parse_fem0_band2_prms(char *l,
	struct wl1271_ini_fem_params_2 *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD2("FEM0_TXBiPReferencePDvoltage_2_4G", l, val,
		&gp->tx_bip_ref_pd_voltage, 1);

	COMPARE_N_ADD("FEM0_TxBiPReferencePower_2_4G", l, val,
		&gp->tx_bip_ref_power, 1);

	COMPARE_N_ADD("FEM0_TxBiPOffsetdB_2_4G", l, val,
		&gp->tx_bip_ref_offset, 1);

	COMPARE_N_ADD("FEM0_TxPerRatePowerLimits_2_4G_Normal", l, val,
		gp->tx_per_rate_pwr_limits_normal,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM0_TxPerRatePowerLimits_2_4G_Degraded", l, val,
		gp->tx_per_rate_pwr_limits_degraded,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM0_TxPerRatePowerLimits_2_4G_Extreme", l, val,
		gp->tx_per_rate_pwr_limits_extreme,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM0_DegradedLowToNormalThr_2_4G", l, val,
		&gp->degraded_low_to_normal_thr, 1);

	COMPARE_N_ADD("FEM0_NormalToDegradedHighThr_2_4G", l, val,
		&gp->normal_to_degraded_high_thr, 1);

	COMPARE_N_ADD("FEM0_TxPerChannelPowerLimits_2_4G_11b", l, val,
		gp->tx_per_chan_pwr_limits_11b,
		WL1271_INI_CHANNEL_COUNT_2);

	COMPARE_N_ADD("FEM0_TxPerChannelPowerLimits_2_4G_OFDM", l, val,
		gp->tx_per_chan_pwr_limits_ofdm,
		WL1271_INI_CHANNEL_COUNT_2);

	COMPARE_N_ADD("FEM0_TxPDVsRateOffsets_2_4G", l, val,
		gp->tx_pd_vs_rate_offsets,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM0_TxIbiasTable_2_4G", l, val,
		gp->tx_ibias,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM0_RxFemInsertionLoss_2_4G", l, val,
		&gp->rx_fem_insertion_loss, 1);

	return 1;
}

static int parse_fem1_band2_prms(char *l,
	struct wl1271_ini_fem_params_2 *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD2("FEM1_TXBiPReferencePDvoltage_2_4G", l, val,
		&gp->tx_bip_ref_pd_voltage, 1);

	COMPARE_N_ADD("FEM1_TxBiPReferencePower_2_4G", l, val,
		&gp->tx_bip_ref_power, 1);

	COMPARE_N_ADD("FEM1_TxBiPOffsetdB_2_4G", l, val,
		&gp->tx_bip_ref_offset, 1);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_2_4G_Normal", l, val,
		gp->tx_per_rate_pwr_limits_normal,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_2_4G_Degraded", l, val,
		gp->tx_per_rate_pwr_limits_degraded,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_2_4G_Extreme", l, val,
		gp->tx_per_rate_pwr_limits_extreme,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_DegradedLowToNormalThr_2_4G", l, val,
		&gp->degraded_low_to_normal_thr, 1);

	COMPARE_N_ADD("FEM1_NormalToDegradedHighThr_2_4G", l, val,
		&gp->normal_to_degraded_high_thr, 1);

	COMPARE_N_ADD("FEM1_TxPerChannelPowerLimits_2_4G_11b", l, val,
		gp->tx_per_chan_pwr_limits_11b,
		WL1271_INI_CHANNEL_COUNT_2);

	COMPARE_N_ADD("FEM1_TxPerChannelPowerLimits_2_4G_OFDM", l, val,
		gp->tx_per_chan_pwr_limits_ofdm,
		WL1271_INI_CHANNEL_COUNT_2);

	COMPARE_N_ADD("FEM1_TxPDVsRateOffsets_2_4G", l, val,
		gp->tx_pd_vs_rate_offsets,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxIbiasTable_2_4G", l, val,
		gp->tx_ibias,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_RxFemInsertionLoss_2_4G", l, val,
		&gp->rx_fem_insertion_loss, 1);

	return 1;
}

static int parse_fem1_band5_prms(char *l,
	struct wl1271_ini_fem_params_5 *gp)
{
	char *name, *val;

	if (split_line(l, &name, &val))
		return 1;

	COMPARE_N_ADD2("FEM1_TXBiPReferencePDvoltage_5G", l, val,
		gp->tx_bip_ref_pd_voltage, WL1271_INI_SUB_BAND_COUNT_5);

	COMPARE_N_ADD("FEM1_TxBiPReferencePower_5G", l, val,
		gp->tx_bip_ref_power, WL1271_INI_SUB_BAND_COUNT_5);

	COMPARE_N_ADD("FEM1_TxBiPOffsetdB_5G", l, val,
		gp->tx_bip_ref_offset, WL1271_INI_SUB_BAND_COUNT_5);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_5G_Normal", l, val,
		gp->tx_per_rate_pwr_limits_normal,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_5G_Degraded", l, val,
		gp->tx_per_rate_pwr_limits_degraded,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxPerRatePowerLimits_5G_Extreme", l, val,
		gp->tx_per_rate_pwr_limits_extreme,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_DegradedLowToNormalThr_5G", l, val,
		&gp->degraded_low_to_normal_thr, 1);

	COMPARE_N_ADD("FEM1_NormalToDegradedHighThr_5G", l, val,
		&gp->normal_to_degraded_high_thr, 1);

	COMPARE_N_ADD("FEM1_TxPerChannelPowerLimits_5G_OFDM", l, val,
		gp->tx_per_chan_pwr_limits_ofdm,
		WL1271_INI_CHANNEL_COUNT_5);

	COMPARE_N_ADD("FEM1_TxPDVsRateOffsets_5G", l, val,
		gp->tx_pd_vs_rate_offsets,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_TxIbiasTable_5G", l, val,
		gp->tx_ibias,
		WL1271_INI_RATE_GROUP_COUNT);

	COMPARE_N_ADD("FEM1_RxFemInsertionLoss_5G", l, val,
		gp->rx_fem_insertion_loss, WL1271_INI_SUB_BAND_COUNT_5);

	return 1;
}

static int find_section(const char *l, enum wl1271_ini_section *st, int *cntr)
{
	if (strncmp("TXBiPFEMAutoDetect", l, 18) == 0) {
		*st = GENERAL_PRMS;
		*cntr = 12;
		return 0;
	}

	if (strncmp("RxTraceInsertionLoss_2_4G", l, 25) == 0) {
		*st = BAND2_PRMS;
		*cntr = 3;
		return 0;
	}

	if (strncmp("RxTraceInsertionLoss_5G", l, 23) == 0) {
		*st = BAND5_PRMS;
		*cntr = 3;
		return 0;
	}

	if (strncmp("FEM0_TXBiPReferencePDvoltage_2_4G", l, 33) == 0) {
		*st = FEM0_BAND2_PRMS;
		*cntr = 13;
		return 0;
	}

	if (strncmp("FEM1_TXBiPReferencePDvoltage_2_4G", l, 33) == 0) {
		*st = FEM1_BAND2_PRMS;
		*cntr = 13;
		return 0;
	}

	if (strncmp("FEM1_TXBiPReferencePDvoltage_5G", l, 31) == 0) {
		*st = FEM1_BAND5_PRMS;
		*cntr = 12;
		return 0;
	}

	return 1;
}

static int ini_parse_line(char *l, int nbr, struct wl1271_ini *ini)
{
	static enum wl1271_ini_section status = UKNOWN_SECTION;
	static int cntr;

	if (!cntr && find_section(l, &status, &cntr)) {
		fprintf(stderr, "Uknown ini section\n");
		return 1;
	}

	switch (status) {
	case GENERAL_PRMS:	/* general parameters */
		cntr--;
		return parse_general_prms(l, &ini->general_params);
	case BAND2_PRMS:	/* band 2.4GHz parameters */
		cntr--;
		return parse_band2_prms(l, &ini->stat_radio_params_2);
	case BAND5_PRMS:	/* band 5GHz parameters */
		cntr--;
		return parse_band5_prms(l, &ini->stat_radio_params_5);
	case FEM0_BAND2_PRMS:	/* FEM0 band 2.4GHz parameters */
		cntr--;
		return parse_fem0_band2_prms(l,
			&(ini->dyn_radio_params_2[0].params));
	case FEM1_BAND2_PRMS:	/* FEM1 band 2.4GHz parameters */
		cntr--;
		return parse_fem1_band2_prms(l,
			&(ini->dyn_radio_params_2[1].params));
	case FEM1_BAND5_PRMS:	/* FEM1 band 5GHz parameters */
		cntr--;
		return parse_fem1_band5_prms(l,
			&(ini->dyn_radio_params_5[1].params));
	}

	return 1;
}
#if 0
static void ini_dump(struct wl1271_ini *ini)
{
	int i;

	printf("\n");
	printf("General params:\n");
	printf("ref clock:                 %02X\n",
		ini->general_params.ref_clock);
	printf("settling time:             %02X\n",
		ini->general_params.settling_time);
	printf("clk valid on wakeup:       %02X\n",
		ini->general_params.clk_valid_on_wakeup);
	printf("dc2dc mode:                %02X\n",
		ini->general_params.dc2dc_mode);
	printf("dual band mode:            %02X\n",
		ini->general_params.dual_mode_select);
	printf("tx bip fem auto detect:    %02X\n",
		ini->general_params.tx_bip_fem_auto_detect);
	printf("tx bip fem manufacturer:   %02X\n",
		ini->general_params.tx_bip_fem_manufacturer);
	printf("general settings:          %02X\n",
		ini->general_params.general_settings);
	printf("sr state:                  %02X\n",
		ini->general_params.sr_state);

	printf("srf1:");
	for (i = 0; i < WL1271_INI_MAX_SMART_REFLEX_PARAM; i++)
		printf(" %02X", ini->general_params.srf1[i]);
	printf("\n");

	printf("srf2:");
	for (i = 0; i < WL1271_INI_MAX_SMART_REFLEX_PARAM; i++)
		printf(" %02X", ini->general_params.srf2[i]);
	printf("\n");

	printf("srf3:");
	for (i = 0; i < WL1271_INI_MAX_SMART_REFLEX_PARAM; i++)
		printf(" %02X", ini->general_params.srf3[i]);
	printf("\n");

	printf("Static 2.4 band params:\n");
	printf("%02X %02X",
		ini->stat_radio_params_2.rx_trace_insertion_loss);
	for (i = 0; i < WL1271_INI_RSSI_PROCESS_COMPENS_SIZE; i++)
		printf(" %02X",
			ini->stat_radio_params_2.rx_rssi_process_compens[i]);
	printf("\n");

	printf("Dynamic 2.4 band params for FEM0\n");

	printf("Dynamic 2.4 band params for FEM0\n");

	printf("Static 5 band params:\n");

	printf("Dynamic 5 band params for FEM0\n");

	printf("Dynamic 5 band params for FEM0\n");

}
#endif
int read_ini(const char *filename, struct wl1271_ini *ini)
{
	FILE *f;
	char buf[1024], *pos;
	int errors = 0, line = 0;

	f = fopen(filename, "r");
	if (f == NULL)
		return 1;

	while (ini_get_line(buf, sizeof(buf), f, &line, &pos))
		ini_parse_line(pos, line, ini);

	fclose(f);
#if 0
	ini_dump(ini);
#endif
	return 0;
}
