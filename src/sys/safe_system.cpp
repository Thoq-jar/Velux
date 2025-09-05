#include "sys.hpp"

std::string sanitize(const std::string& command) {
    std::string sanitized;
    for(const char c : command) {
        if(strchr("&;`'\"|*?~^()[]{}$\\\n-", c))
            sanitized += '\\';

        sanitized += c;
    }

    return sanitized;
}

int Sys::safe_system(const std::string& command) {
    if(command.empty())
        return -1;

    const std::string sanitized = sanitize(command);

    return system(sanitized.c_str());
}

int Sys::safe_system(const std::string& command, bool silent) {
    if(command.empty())
        return -1;

    const std::string sanitized = sanitize(command);
    const int result = silent ? system((sanitized + " > /dev/null 2>&1").c_str()) : system(sanitized.c_str());

    return WEXITSTATUS(result);
}