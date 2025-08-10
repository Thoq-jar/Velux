#include "sys.hpp"

int Sys::safe_system(const std::string& command) {
    if(command.empty()) {
        return -1;
    }

    std::string sanitized;
    for(const char c : command) {
        if(strchr("&;`'\"|*?~<>^()[]{}$\\\n", c)) {
            sanitized += '\\';
        }
        sanitized += c;
    }

    return system(sanitized.c_str());
}

int Sys::safe_system(const std::string& command, bool silent) {
    if(command.empty()) {
        return -1;
    }

    std::string sanitized;
    for(const char c : command) {
        if(strchr("&;`'\"|*?~<>^()[]{}$\\\n", c)) {
            sanitized += '\\';
        }
        sanitized += c;
    }

    const int result = silent ? system((sanitized + " > /dev/null 2>&1").c_str()) : system(sanitized.c_str());
    return WEXITSTATUS(result);
}
