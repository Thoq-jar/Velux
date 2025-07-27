#ifndef CORE_H
#define CORE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  char *name;
  int version_major;
  int version_minor;
  int version_patch;
} core_info_t;

typedef struct {
  char *message;
  int level;
  long timestamp;
} log_entry_t;

core_info_t *core_get_info(void);
void core_free_info(core_info_t *info);

int core_init(void);
void core_cleanup(void);

void core_log(int level, const char *message);
log_entry_t *core_get_last_log(void);
void core_free_log_entry(log_entry_t *entry);

int core_process_data(const char *input, char **output);
void core_free_output(char *output);

#define CORE_LOG_ERROR 0
#define CORE_LOG_WARNING 1
#define CORE_LOG_INFO 2
#define CORE_LOG_DEBUG 3

#endif