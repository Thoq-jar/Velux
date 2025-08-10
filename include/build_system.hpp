#ifndef BUILD_SYSTEM_HPP
#define BUILD_SYSTEM_HPP

#include "configparse.h"

class BuildSystem {
public:
    static void build(const ConfigParse::Config& config);
    static std::string executeCommand(const std::string& command);
    static void addPkgConfigFlags(const ConfigParse::Config& config, std::string& build_cmd);
    static void addDependencyLibraries(const ConfigParse::Config& config, std::string& build_cmd);

private:
    static void generateNinjaFile(const ConfigParse::Config& config, const std::string& compiler);
    static std::string getPkgConfigFlags(const ConfigParse::Config& config);
    static void addDependencyLibrariesString(const ConfigParse::Config& config, std::string& ldflags);
    static void buildDependency(const std::string& dependencyPath);
    static std::string getDependencyLibraryPath(const std::string& dependencyPath);
};

#endif // BUILD_SYSTEM_HPP
