#include "build_system.hpp"
#include "configparse.h"
#include "logger.hpp"
#include "sys.hpp"
#include <filesystem>
#include <cstdio>
#include <memory>

void BuildSystem::build(const ConfigParse::Config& config) {
    Logger::info("Parsing config...", "Builder");

    if(!config.dependencies.empty()) {
        Logger::info("Building dependencies...", "Builder");
        for(const std::string& dependency : config.dependencies) {
            buildDependency(dependency);
        }
    }

    const std::string target = config.output;
    const std::vector<std::string> compilers = config.compilers;
    const std::vector<std::string> sources = config.sources;
    const std::vector<std::string> flags = config.flags;
    const std::string language = config.language;

    std::string build_cmd;
    std::string compiler;

    Logger::info("Finding Compiler...", "Builder");
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

    if(config.type == "library") {
        build_cmd += "ar rcs " + target + " ";

        for(const auto& src : sources) {
            std::string obj_cmd = compiler + " ";
            obj_cmd += config.language == "CXX" ? "-std=c++" + config.version + " " : "-std=c" + config.version + " ";
            obj_cmd += "-c " + src + " ";

            for(const auto& flag : flags) {
                obj_cmd += flag + " ";
            }

            for(const auto& inc : config.include) {
                obj_cmd += "-I" + inc + " ";
            }

            addPkgConfigFlags(config, obj_cmd);

            Sys::safe_system(obj_cmd);
        }

        for(const auto& src : sources) {
            std::string obj_file = src.substr(0, src.find_last_of('.')) + ".o";
            build_cmd += obj_file + " ";
        }
    } else {
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

        addPkgConfigFlags(config, build_cmd);
        addDependencyLibraries(config, build_cmd);
    }

    Logger::info("Building main project...", "Builder");
    Sys::safe_system(build_cmd);
}

std::string BuildSystem::executeCommand(const std::string& command) {
    const std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(command.c_str(), "r"), pclose);
    if(!pipe) {
        throw std::runtime_error("popen() failed!");
    }

    std::string result;
    char buffer[128];
    while(fgets(buffer, sizeof buffer, pipe.get()) != nullptr) {
        result += buffer;
    }

    if(!result.empty() && result.back() == '\n') {
        result.pop_back();
    }

    return result;
}

void BuildSystem::addPkgConfigFlags(const ConfigParse::Config& config, std::string& build_cmd) {
    if(config.find_pkg.empty()) {
        return;
    }

    Logger::info("Using pkg-config for packages...", "Builder-Configurator");

    if(!Sys::safe_system("pkg-config", true)) {
        Logger::error("pkg-config is not available on this system!", "Builder-Configurator");
        exit(1);
    }

    for(const std::string& package : config.find_pkg) {
        if(std::string check_cmd = "pkg-config --exists " + package; !Sys::safe_system(check_cmd, true)) {
            Logger::error("Package '" + package + "' not found by pkg-config!", "Builder-Configurator");
            exit(1);
        }
    }

    std::string pkg_config_cmd = "pkg-config --cflags --libs ";
    for(const std::string& package : config.find_pkg) {
        pkg_config_cmd += package + " ";
    }

    try {
        if(const std::string pkg_flags = executeCommand(pkg_config_cmd); !pkg_flags.empty()) {
            build_cmd += pkg_flags + " ";
            Logger::info("Added pkg-config flags: " + pkg_flags, "Builder-Configurator");
        }
    } catch(const std::exception& e) {
        Logger::error("Failed to execute pkg-config: " + std::string(e.what()), "Builder-Configurator");
        exit(1);
    }
}

void BuildSystem::addDependencyLibraries(const ConfigParse::Config& config, std::string& build_cmd) {
    if(config.dependencies.empty()) {
        return;
    }

    for(const std::string& dependency : config.dependencies) {
        if(std::string dep_lib = getDependencyLibraryPath(dependency); !dep_lib.empty()) {
            build_cmd += dep_lib + " ";
        }
    }
}

void BuildSystem::buildDependency(const std::string& dependencyPath) {
    Logger::info("Building dependency: " + dependencyPath, "Builder-Dependency");

    if(!std::filesystem::exists(dependencyPath)) {
        Logger::error("Dependency path does not exist: " + dependencyPath, "Builder-Dependency");
        return;
    }

    const std::string configPath = dependencyPath + "/velux.json";
    if(!std::filesystem::exists(configPath)) {
        Logger::error("No velux.json found in dependency: " + dependencyPath, "Builder-Dependency");
        return;
    }

    try {
        const ConfigParse::Config depConfig = ConfigParse::parseConfigFromFile(configPath);
        const std::string originalDir = std::filesystem::current_path();

        std::filesystem::current_path(dependencyPath);

        build(depConfig);

        std::filesystem::current_path(originalDir);

        Logger::info("Successfully built dependency: " + dependencyPath, "Builder-Dependency");
    } catch(const std::exception& e) {
        Logger::error("Failed to build dependency " + dependencyPath + ": " + e.what(), "Builder-Dependency");
        exit(1);
    }
}

std::string BuildSystem::getDependencyLibraryPath(const std::string& dependencyPath) {
    const std::string configPath = dependencyPath + "/velux.json";

    try {
        const ConfigParse::Config depConfig = ConfigParse::parseConfigFromFile(configPath);

        if(std::string libPath = dependencyPath + "/" + depConfig.output; std::filesystem::exists(libPath)) {
            return libPath;
        }
    } catch(const std::exception& ex) {
        Logger::error(ex.what(), "Builder-Resolver");
        Logger::error("Could not determine library path for dependency: " + dependencyPath, "Builder-Resolver");
    }

    return "";
}
