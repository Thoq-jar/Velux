#include "../src/core/core.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void test_core_info(void) {
  printf("Testing core_get_info...\n");

  core_info_t *info = core_get_info();
  assert(info != NULL);
  assert(info->name != NULL);
  assert(strcmp(info->name, "VeluxCore") == 0);
  assert(info->version_major == 1);
  assert(info->version_minor == 0);
  assert(info->version_patch == 0);

  printf("✓ core_get_info passed\n");
}

void test_core_init_cleanup(void) {
  printf("Testing core_init and core_cleanup...\n");

  int result = core_init();
  assert(result == 0);

  result = core_init();
  assert(result == 1);

  core_cleanup();

  result = core_init();
  assert(result == 0);

  core_cleanup();

  printf("✓ core_init and core_cleanup passed\n");
}

void test_core_logging(void) {
  printf("Testing core logging...\n");

  core_init();

  core_log(CORE_LOG_INFO, "Test info message");
  log_entry_t *log = core_get_last_log();
  assert(log != NULL);
  assert(log->message != NULL);
  assert(strcmp(log->message, "Test info message") == 0);
  assert(log->level == CORE_LOG_INFO);
  assert(log->timestamp > 0);

  core_log(CORE_LOG_ERROR, "Test error message");
  log = core_get_last_log();
  assert(log != NULL);
  assert(strcmp(log->message, "Test error message") == 0);
  assert(log->level == CORE_LOG_ERROR);

  core_cleanup();

  printf("✓ core logging passed\n");
}

void test_core_process_data(void) {
  printf("Testing core_process_data...\n");

  core_init();

  char *output = NULL;
  int result = core_process_data("test input", &output);
  assert(result == 0);
  assert(output != NULL);
  assert(strstr(output, "Processed: test input") != NULL);
  assert(strstr(output, "length: 10") != NULL);

  core_free_output(output);

  result = core_process_data(NULL, &output);
  assert(result == -1);

  output = NULL;
  result = core_process_data("valid input", NULL);
  assert(result == -1);

  core_cleanup();

  printf("✓ core_process_data passed\n");
}

void test_memory_management(void) {
  printf("Testing memory management...\n");

  core_init();

  core_info_t *info = core_get_info();
  assert(info != NULL);
  assert(info->name != NULL);

  core_cleanup();

  core_init();
  info = core_get_info();
  assert(info != NULL);
  assert(info->name != NULL);

  core_cleanup();

  printf("✓ memory management passed\n");
}

int main(void) {
  printf("Running Core Library Tests\n");
  printf("==========================\n\n");

  test_core_info();
  test_core_init_cleanup();
  test_core_logging();
  test_core_process_data();
  test_memory_management();

  printf("\n✅ All tests passed successfully!\n");

  return 0;
}