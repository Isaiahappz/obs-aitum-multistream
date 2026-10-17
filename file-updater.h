#pragma once

#include <util/darray.h>

struct update_info;
typedef struct update_info update_info_t;

struct file_download_data {
	const char *name;
	int version;

	DARRAY(uint8_t) buffer;
};

/* Invoked on the updater's worker thread once the file has been fetched.
 * It must not call update_info_destroy(): that would join the thread it is
 * running on. */
typedef bool (*confirm_file_callback_t)(void *param, struct file_download_data *file);

/* The returned handle is owned by the caller, whether or not the download
 * succeeds and whether or not confirm_callback ever runs. Release it with
 * update_info_destroy(), which joins the worker thread. */
update_info_t *update_info_create_single(const char *log_prefix, const char *user_agent, const char *file_url,
					 confirm_file_callback_t confirm_callback, void *param);
void update_info_destroy(update_info_t *info);
