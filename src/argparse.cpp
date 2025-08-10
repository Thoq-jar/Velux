#include "argparse.hpp"

#include <functional>
#include <iostream>
#include <unordered_map>
#include <string>

#include "logger.hpp"

Option ArgParse::parse(const int count, const char* args[]) {
    std::unordered_map<std::string, std::function<void(Option&, const std::string&)>> cli_flags = {
        {"--verbose", [](Option& opt, const std::string&) -> void { opt.verbose = true; }},
        {"-v", [](Option& opt, const std::string&) -> void { opt.verbose = true; }},
        {"-c", [](Option& opt, const std::string& value) -> void { opt.config_file = value; }},
        {"--help", [](Option&, const std::string&) -> void {
            std::cout << "Usage: program [options] <command>\n"
                      << "Options:\n"
                      << "  -v, --verbose    Enable verbose output\n"
                      << "  -c, --config     Specify config file\n"
                      << "  --help           Show this help message\n";
            exit(0);
        }}
    };

    Option option = {
        .verbose = false,
        .config_file = std::nullopt,
        .command = ""
    };

    for(int i = 1; i < count; ++i) {
        std::string arg = args[i];

        if(arg[0] != '-') {
            option.command = arg;
            continue;
        }

        auto it = cli_flags.find(arg);
        if(it == cli_flags.end()) {
            Logger::error("Unknown Option: " + arg, "Main");
            exit(1);
        }

        if(arg != "--config" && arg != "-c") {
            it->second(option, "");
            continue;
        }

        if(i + 1 >= count) {
            Logger::error(arg + " requires a value!", "Main");
            exit(1);
        }

        it->second(option, args[++i]);
    }

    return option;
}
