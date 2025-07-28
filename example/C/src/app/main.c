#include "../core/core.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void print_usage(const char *program_name) {
  printf("Usage: %s [options] [input]\n", program_name);
  printf("Options:\n");
  printf("  -h, --help     Show this help message\n");
  printf("  -v, --version  Show version information\n");
  printf("  -d, --debug    Enable debug logging\n");
  printf("  input          Input string to process\n");
}

void print_version(void) {
  core_info_t *info = core_get_info();
  if (info) {
    printf("%s v%d.%d.%d\n", info->name, info->version_major,
           info->version_minor, info->version_patch);
  }
}

int main(int argc, char *argv[]) {
  int debug_mode = 0;
  char *input_data = NULL;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
      print_usage(argv[0]);
      return 0;
    } else if (strcmp(argv[i], "-v") == 0 ||
               strcmp(argv[i], "--version") == 0) {
      print_version();
      return 0;
    } else if (strcmp(argv[i], "-d") == 0 || strcmp(argv[i], "--debug") == 0) {
      debug_mode = 1;
    } else if (input_data == NULL) {
      input_data = argv[i];
    }
  }

  if (core_init() != 0) {
    fprintf(stderr, "Failed to initialize core library\n");
    return 1;
  }

  if (debug_mode) {
    core_log(CORE_LOG_DEBUG, "Debug mode enabled");
  }

  printf("Welcome to Velux Demo Application\n");
  print_version();
  printf("\n");

  if (input_data == NULL) {
    printf("No input provided, using default data\n");
    input_data = "Hello, Velux!";
  }

  core_log(CORE_LOG_INFO, "Processing input data");

  char *output = NULL;
  int result = core_process_data(input_data, &output);

  if (result == 0 && output) {
    printf("Result: %s\n", output);
    core_free_output(output);
  } else {
    core_log(CORE_LOG_ERROR, "Failed to process data");
    core_cleanup();
    return 1;
  }

  log_entry_t *last_log = core_get_last_log();
  if (last_log && last_log->message) {
    printf("Last log: %s (level: %d)\n", last_log->message, last_log->level);
  }

  core_cleanup();
  printf("Application finished successfully\n");

  return 0;
}