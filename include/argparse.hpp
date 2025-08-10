#ifndef ARGPARSE_HPP
#define ARGPARSE_HPP

#include <optional>
#include <string>
#include <unordered_map>

struct Option {
    bool verbose = false;
    std::optional<std::string> config_file = "velux.json";
    std::string command;
};

class ArgParse {
public:
    static auto parse(int count, const char* args[]) -> Option;
};

#endif // ARGPARSE_HPP
