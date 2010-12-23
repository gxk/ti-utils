/*
 * This file is part of wl1271
 *
 * Copyright (C) 2010 Nokia Corporation
 *
 * Contact: Luciano Coelho <luciano.coelho@nokia.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 *
 */

#ifndef __INI_H__
#define __INI_H__

#define WL1271_INI_MAX_SMART_REFLEX_PARAM 16

struct wl1271_ini_general_params {
	unsigned char ref_clock;
	unsigned char settling_time;
	unsigned char clk_valid_on_wakeup;
	unsigned char dc2dc_mode;
	unsigned char dual_mode_select;
	unsigned char tx_bip_fem_auto_detect;
	unsigned char tx_bip_fem_manufacturer;
	unsigned char general_settings;
	unsigned char sr_state;
	unsigned char srf1[WL1271_INI_MAX_SMART_REFLEX_PARAM];
	unsigned char srf2[WL1271_INI_MAX_SMART_REFLEX_PARAM];
	unsigned char srf3[WL1271_INI_MAX_SMART_REFLEX_PARAM];
} __attribute__((packed));

#define WL1271_INI_RSSI_PROCESS_COMPENS_SIZE 15

struct wl1271_ini_band_params_2 {
	unsigned char rx_trace_insertion_loss;
	unsigned char tx_trace_loss;
	unsigned char
		rx_rssi_process_compens[WL1271_INI_RSSI_PROCESS_COMPENS_SIZE];
} __attribute__((packed));

#define WL1271_INI_RATE_GROUP_COUNT 6
#define WL1271_INI_CHANNEL_COUNT_2 14

struct wl1271_ini_fem_params_2 {
	__le16 tx_bip_ref_pd_voltage;
	unsigned char tx_bip_ref_power;
	unsigned char tx_bip_ref_offset;
	unsigned char
		tx_per_rate_pwr_limits_normal[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char
		tx_per_rate_pwr_limits_degraded[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char
		tx_per_rate_pwr_limits_extreme[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char tx_per_chan_pwr_limits_11b[WL1271_INI_CHANNEL_COUNT_2];
	unsigned char tx_per_chan_pwr_limits_ofdm[WL1271_INI_CHANNEL_COUNT_2];
	unsigned char tx_pd_vs_rate_offsets[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char tx_ibias[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char rx_fem_insertion_loss;
	unsigned char degraded_low_to_normal_thr;
	unsigned char normal_to_degraded_high_thr;
} __attribute__((packed));

#define WL1271_INI_CHANNEL_COUNT_5 35
#define WL1271_INI_SUB_BAND_COUNT_5 7

struct wl1271_ini_band_params_5 {
	unsigned char rx_trace_insertion_loss[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char tx_trace_loss[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char
		rx_rssi_process_compens[WL1271_INI_RSSI_PROCESS_COMPENS_SIZE];
} __attribute__((packed));

struct wl1271_ini_fem_params_5 {
	__le16 tx_bip_ref_pd_voltage[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char tx_bip_ref_power[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char tx_bip_ref_offset[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char
		tx_per_rate_pwr_limits_normal[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char
		tx_per_rate_pwr_limits_degraded[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char
		tx_per_rate_pwr_limits_extreme[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char tx_per_chan_pwr_limits_ofdm[WL1271_INI_CHANNEL_COUNT_5];
	unsigned char tx_pd_vs_rate_offsets[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char tx_ibias[WL1271_INI_RATE_GROUP_COUNT];
	unsigned char rx_fem_insertion_loss[WL1271_INI_SUB_BAND_COUNT_5];
	unsigned char degraded_low_to_normal_thr;
	unsigned char normal_to_degraded_high_thr;
} __attribute__((packed));


/* NVS data structure */
#define WL1271_INI_NVS_SECTION_SIZE		     468
#define WL1271_INI_FEM_MODULE_COUNT                  2

#define WL1271_INI_LEGACY_NVS_FILE_SIZE              800

struct wl1271_nvs_file {
	/* NVS section */
	unsigned char nvs[WL1271_INI_NVS_SECTION_SIZE];

	/* INI section */
	struct wl1271_ini_general_params general_params;
	unsigned char padding1;
	struct wl1271_ini_band_params_2 stat_radio_params_2;
	unsigned char padding2;
	struct {
		struct wl1271_ini_fem_params_2 params;
		unsigned char padding;
	} dyn_radio_params_2[WL1271_INI_FEM_MODULE_COUNT];
	struct wl1271_ini_band_params_5 stat_radio_params_5;
	unsigned char padding3;
	struct {
		struct wl1271_ini_fem_params_5 params;
		unsigned char padding;
	} dyn_radio_params_5[WL1271_INI_FEM_MODULE_COUNT];
} __attribute__((packed));

struct wl1271_ini {
	struct wl1271_ini_general_params general_params;
	unsigned char padding1;
	struct wl1271_ini_band_params_2 stat_radio_params_2;
	unsigned char padding2;
	struct {
		struct wl1271_ini_fem_params_2 params;
		unsigned char padding;
	} dyn_radio_params_2[WL1271_INI_FEM_MODULE_COUNT];
	struct wl1271_ini_band_params_5 stat_radio_params_5;
	unsigned char padding3;
	struct {
		struct wl1271_ini_fem_params_5 params;
		unsigned char padding;
	} dyn_radio_params_5[WL1271_INI_FEM_MODULE_COUNT];
} __attribute__((packed));

enum wl1271_ini_section {
	UKNOWN_SECTION,
	GENERAL_PRMS,
	BAND2_PRMS,
	BAND5_PRMS,
	FEM0_BAND2_PRMS,
	FEM1_BAND2_PRMS,
	FEM1_BAND5_PRMS
};

#endif
