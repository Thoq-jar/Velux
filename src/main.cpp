#include "argparse.hpp"
#include "build_system.hpp"
#include "logger.hpp"
#include "configparse.h"
#include "sys.hpp"

int main(const int argc, const char** argv) {
    Logger::info("Starting Velux...", "Bootstrap");

    const auto argparse = ArgParse::parse(argc, argv);
    const std::string config_content = Sys::read_to_string(argparse.config_file.value_or("velux.json"));
    const auto config = ConfigParse::parseConfig(config_content);

    BuildSystem::build(config);

    return 0;
}
