#define _GNU_SOURCE
#include "core.h"
#include <time.h>

static core_info_t g_core_info = {0};
static log_entry_t g_last_log = {0};
static int g_initialized = 0;

core_info_t *core_get_info(void) {
  if (g_core_info.name == NULL) {
    g_core_info.name = strdup("VeluxCore");
    g_core_info.version_major = 1;
    g_core_info.version_minor = 0;
    g_core_info.version_patch = 0;
  }
  return &g_core_info;
}

void core_free_info(core_info_t *info) {
  if (info && info->name) {
    free(info->name);
    info->name = NULL;
  }
}

int core_init(void) {
  if (g_initialized) {
    return 1;
  }

  core_log(CORE_LOG_INFO, "Core initialized");
  g_initialized = 1;
  return 0;
}

void core_cleanup(void) {
  if (!g_initialized) {
    return;
  }

  core_log(CORE_LOG_INFO, "Core cleanup");

  if (g_core_info.name) {
    free(g_core_info.name);
    g_core_info.name = NULL;
  }

  if (g_last_log.message) {
    free(g_last_log.message);
    g_last_log.message = NULL;
  }

  g_initialized = 0;
}

void core_log(int level, const char *message) {
  if (g_last_log.message) {
    free(g_last_log.message);
  }

  g_last_log.message = strdup(message);
  g_last_log.level = level;
  g_last_log.timestamp = time(NULL);

  const char *level_str;
  switch (level) {
  case CORE_LOG_ERROR:
    level_str = "ERROR";
    break;
  case CORE_LOG_WARNING:
    level_str = "WARN";
    break;
  case CORE_LOG_INFO:
    level_str = "INFO";
    break;
  case CORE_LOG_DEBUG:
    level_str = "DEBUG";
    break;
  default:
    level_str = "UNKNOWN";
    break;
  }

  printf("[%s] %s\n", level_str, message);
}

log_entry_t *core_get_last_log(void) { return &g_last_log; }

void core_free_log_entry(log_entry_t *entry) {
  if (entry && entry->message) {
    free(entry->message);
    entry->message = NULL;
  }
}

int core_process_data(const char *input, char **output) {
  if (!input || !output) {
    core_log(CORE_LOG_ERROR, "Invalid input or output pointer");
    return -1;
  }

  size_t input_len = strlen(input);
  size_t output_len = input_len + 32;

  *output = malloc(output_len);
  if (!*output) {
    core_log(CORE_LOG_ERROR, "Memory allocation failed");
    return -1;
  }

  snprintf(*output, output_len, "Processed: %s (length: %zu)", input,
           input_len);

  core_log(CORE_LOG_DEBUG, "Data processed successfully");
  return 0;
}

void core_free_output(char *output) {
  if (output) {
    free(output);
  }
}
