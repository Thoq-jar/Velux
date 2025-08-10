cmake_minimum_required(VERSION 4.0)
project(velux)

set(CMAKE_CXX_STANDARD 26)

include_directories(include third_party)

set(SOURCES
        src/main.cpp
        src/argparse.cpp
        src/logger.cpp
        src/configparse.cpp
        src/sys/fs.cpp
        src/build_system.cpp
        src/sys/safe_system.cpp
)

set(THIRD_PARTY
        "third_party/cJSON/cJSON.c"
        "third_party/cJSON/cJSON.h"
)

add_executable(velux ${SOURCES} ${THIRD_PARTY})
