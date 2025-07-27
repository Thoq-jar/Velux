cmake_minimum_required(VERSION 3.16)
project(VeluxDemo VERSION 1.0.0 LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -g -O0")
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O3 -DNDEBUG")

add_library(core SHARED
    src/core/core.c
)

target_include_directories(core PUBLIC
    src/core
)

add_executable(velux-app
    src/app/main.c
)

target_link_libraries(velux-app PRIVATE core)

target_include_directories(velux-app PRIVATE
    src/core
)

add_executable(test_runner
    tests/test_core.c
)

target_link_libraries(test_runner PRIVATE core)

target_include_directories(test_runner PRIVATE
    src/core
)

enable_testing()
add_test(NAME CoreTests COMMAND test_runner)

install(TARGETS core velux-app
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)

install(FILES src/core/core.h
    DESTINATION include
)
