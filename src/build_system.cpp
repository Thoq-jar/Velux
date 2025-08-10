#include "build_system.hpp"
#include "configparse.h"
#include "logger.hpp"
#include "sys.hpp"

void BuildSystem::build(const ConfigParse::Config& config) {
    Logger::info("Parsing config...", "Builder");
    const std::string target = config.output;
    const std::vector<std::string> compilers = config.compilers;
    const std::vector<std::string> sources = config.sources;
    const std::vector<std::string> flags = config.flags;
    const std::string language = config.language;

    Logger::info("Finding Compiler...", "Builder");
    std::string compiler;
    for(const std::string& c : compilers) {
        if(Sys::safe_system(c, true)) {
            compiler = c;
            break;
        }
    }

    if(compiler.empty()) {
        Logger::error("Could not find suitable compiler!", "Builder");
        exit(1);
    }

    Logger::info("Configuring " + compiler + "...", "Builder");
    std::string build_cmd;
    build_cmd += compiler + " ";
    build_cmd += "-o " + target + " ";
    build_cmd += config.language == "CXX" ? "-std=c++" + config.version + " " : "-std=c" + config.version + " ";
    for(const auto& flag : flags) {
        build_cmd += flag + " ";
    }
    for(const auto& src : sources) {
        build_cmd += src + " ";
    }
    for(const auto& inc : config.include) {
        build_cmd += "-I" + inc + " ";
    }

    Logger::info("Building...", "Builder");
    Sys::safe_system(build_cmd);
}
