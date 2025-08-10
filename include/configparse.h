#ifndef VELUX_CONFIGPARSE_H
#define VELUX_CONFIGPARSE_H
#include <string>
#include <vector>

class ConfigParse {
public:
    struct Config {
        std::string velux;
        std::string language;
        std::string version;
        std::string type;
        std::string output;
        std::vector<std::string> compilers;
        std::vector<std::string> flags;
        std::vector<std::string> sources;
        std::vector<std::string> include;
        std::vector<std::string> find_pkg;
        std::vector<std::string> dependencies;  // not implemented yet
    };

    static Config parseConfig(const std::string& jsonString);
    static Config parseConfigFromFile(const std::string& filename);
};

#endif //VELUX_CONFIGPARSE_H
