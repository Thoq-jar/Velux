#include <fstream>
#include <sstream>
#include <stdexcept>
#include "sys.hpp"

std::string Sys::read_to_string(const std::filesystem::path& file_path) {
    std::ifstream file(file_path, std::ios::binary);

    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + file_path.string());
    }

    file.seekg(0, std::ios::end);
    std::size_t size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::string content(size, '\0');
    file.read(content.data(), size);

    if (file.bad()) {
        throw std::runtime_error("Error reading file: " + file_path.string());
    }

    return content;
}
