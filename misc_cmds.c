#include <stdbool.h>
#include <errno.h>
#include <net/if.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>

#include "calibrator.h"
#include "plt.h"
#include "ini.h"

SECTION(get);
SECTION(set);

static int handle_push_nvs(struct nl80211_state *state,
			struct nl_cb *cb,
			struct nl_msg *msg,
			int argc, char **argv)
{
	char *end;
	void *map = MAP_FAILED;
	int fd, retval = 0;
	struct nlattr *key;
	struct stat filestat;

	if (argc != 1)
		return 1;

	fd = open(argv[0], O_RDONLY);
	if (fd < 0) {
		perror("Error opening file for reading");
		return 1;
	}

	if (fstat(fd, &filestat) < 0) {
		perror("Error stating file");
		return 1;
	}

	map = mmap(0, filestat.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (map == MAP_FAILED) {
		perror("Error mmapping the file");
		goto nla_put_failure;
	}

	key = nla_nest_start(msg, NL80211_ATTR_TESTDATA);
	if (!key)
		goto nla_put_failure;

	NLA_PUT_U32(msg, WL1271_TM_ATTR_CMD_ID, WL1271_TM_CMD_NVS_PUSH);
	NLA_PUT(msg, WL1271_TM_ATTR_DATA, filestat.st_size, map);

	nla_nest_end(msg, key);

	goto cleanup;

nla_put_failure:
	retval = -ENOBUFS;

cleanup:
	if (map != MAP_FAILED)
		munmap(map, filestat.st_size);

	close(fd);

	return retval;
}

COMMAND(set, push_nvs, "<nvs filename>",
	NL80211_CMD_TESTMODE, 0, CIB_PHY, handle_push_nvs,
	"Push NVS file into the system");
#if 0
static int handle_fetch_nvs(struct nl80211_state *state,
			struct nl_cb *cb,
			struct nl_msg *msg,
			int argc, char **argv)
{
	char *end;
	void *map = MAP_FAILED;
	int fd, retval = 0;
	struct nlattr *key;
	struct stat filestat;

	if (argc != 0)
		return 1;

	key = nla_nest_start(msg, NL80211_ATTR_TESTDATA);
	if (!key)
		goto nla_put_failure;

	NLA_PUT_U32(msg, WL1271_TM_ATTR_CMD_ID, WL1271_TM_CMD_NVS_PUSH);
	NLA_PUT_U32(msg, WL1271_TM_ATTR_IE_ID, WL1271_TM_CMD_NVS_PUSH);

	nla_nest_end(msg, key);

	goto cleanup;

nla_put_failure:
	retval = -ENOBUFS;

cleanup:
	if (map != MAP_FAILED)
		munmap(map, filestat.st_size);

	close(fd);

	return retval;
}

COMMAND(set, fetch_nvs, NULL,
	NL80211_CMD_TESTMODE, 0, CIB_NETDEV, handle_fetch_nvs,
	"Send command to fetch NVS file");
#endif
static int get_nvs_mac(struct nl80211_state *state, struct nl_cb *cb,
			struct nl_msg *msg, int argc, char **argv)
{
	unsigned char mac_buff[12];
	int fd;

	argc -= 2;
	argv += 2;

	if (argc != 1)
		return 2;

	fd = open(argv[0], O_RDONLY);
	if (fd < 0) {
		perror("Error opening file for reading");
		return 1;
	}

	read(fd, mac_buff, 12);

	printf("MAC addr from NVS: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_buff[11], mac_buff[10], mac_buff[6],
		mac_buff[5], mac_buff[4], mac_buff[3]);

	close(fd);

	return 0;
}

COMMAND(get, nvs_mac, "<nvs filename>", 0, 0, CIB_NONE, get_nvs_mac,
	"Get MAC addr from NVS file (offline)");

static int set_nvs_mac(struct nl80211_state *state, struct nl_cb *cb,
			struct nl_msg *msg, int argc, char **argv)
{
	unsigned char mac_buff[12];
	unsigned char in_mac[6];
	int fd;

	argc -= 2;
	argv += 2;

	if (argc != 2 || strlen(argv[0]) != 17)
		return 2;

	sscanf(argv[0], "%2x:%2x:%2x:%2x:%2x:%2x",
		(unsigned int *)&in_mac[0], (unsigned int *)&in_mac[1],
		(unsigned int *)&in_mac[2], (unsigned int *)&in_mac[3],
		(unsigned int *)&in_mac[4], (unsigned int *)&in_mac[5]);

	fd = open(argv[1], O_RDWR);
	if (fd < 0) {
		perror("Error opening file for reading");
		return 1;
	}

	read(fd, mac_buff, 12);

	printf("Got MAC addr from NVS: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_buff[11], mac_buff[10], mac_buff[6],
		mac_buff[5], mac_buff[4], mac_buff[3]);

	mac_buff[11] = in_mac[0];
	mac_buff[10] = in_mac[1];
	mac_buff[6]  = in_mac[2];
	mac_buff[5]  = in_mac[3];
	mac_buff[4]  = in_mac[4];
	mac_buff[3]  = in_mac[5];

	lseek(fd, 0L, 0);

	write(fd, mac_buff, 12);

	close(fd);

	return 0;
}

COMMAND(set, nvs_mac, "<mac addr> <nvs file>", 0, 0, CIB_NONE, set_nvs_mac,
	"Set MAC addr in NVS file (offline), like XX:XX:XX:XX:XX:XX");

static int set_ref_nvs(struct nl80211_state *state, struct nl_cb *cb,
			struct nl_msg *msg, int argc, char **argv)
{
	struct wl12xx_common cmn = {
		.arch = UNKNOWN_ARCH,
		.parse_ops = NULL
	};

	argc -= 2;
	argv += 2;

	if (argc != 1)
		return 1;

	if (read_ini(*argv, &cmn)) {
		fprintf(stderr, "Fail to read ini file\n");
		return 1;
	}

	cfg_nvs_ops(&cmn);

	if (create_nvs_file(&cmn)) {
		fprintf(stderr, "Fail to prepare new NVS file\n");
		return 1;
	}

	printf("\n\tThe NVS file (%s) is ready\n\tCopy it to %s and "
		"reboot the system\n\n",
		NEW_NVS_NAME, CURRENT_NVS_NAME);

	return 0;
}

COMMAND(set, ref_nvs, "<ini file>", 0, 0, CIB_NONE, set_ref_nvs,
	"Create reference NVS file");

static int set_upd_nvs(struct nl80211_state *state, struct nl_cb *cb,
			struct nl_msg *msg, int argc, char **argv)
{
	char *fname = NULL;
	struct wl12xx_common cmn = {
		.arch = UNKNOWN_ARCH,
		.parse_ops = NULL
	};

	argc -= 2;
	argv += 2;

	if (argc < 1)
		return 1;

	if (read_ini(*argv, &cmn)) {
		fprintf(stderr, "Fail to read ini file\n");
		return 1;
	}

	cfg_nvs_ops(&cmn);

	if (argc == 2)
		fname = *++argv;

	if (update_nvs_file(fname, &cmn)) {
		fprintf(stderr, "Fail to prepare new NVS file\n");
		return 1;
	}

	printf("\n\tThe updated NVS file (%s) is ready\n\tCopy it to %s and "
		"reboot the system\n\n",
		NEW_NVS_NAME, CURRENT_NVS_NAME);

	return 0;
}

COMMAND(set, upd_nvs, "<ini file> [<nvs file>]", 0, 0, CIB_NONE, set_upd_nvs,
	"Update values of a NVS from INI file");
