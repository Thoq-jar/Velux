#ifndef FS_HPP
#define FS_HPP

#include <filesystem>
#include <string>

class Sys {
public:
    static std::string read_to_string(const std::filesystem::path& file_path);
    static int safe_system(const std::string& command);
    static int safe_system(const std::string& command, bool silent);
};

#endif // FS_HPP
