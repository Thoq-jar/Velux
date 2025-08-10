#ifndef BUILD_SYSTEM_HPP
#define BUILD_SYSTEM_HPP

#include "configparse.h"

class BuildSystem {
public:
    static void build(const ConfigParse::Config& config);
};

#endif // BUILD_SYSTEM_HPP
