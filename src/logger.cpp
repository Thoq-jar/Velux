#include <print>
#include <logger.hpp>

Colors color;

void Logger::info(const std::string& message, const std::string& task) {
    std::print("{}[ {}INFO/{} {}]{} {}\n", color.gray, color.purple, task, color.gray, color.reset, message);
}

void Logger::info(const std::string& message) {
    std::print("{}[ {}INFO {}]{} {}\n", color.gray, color.purple, color.gray, color.reset, message);
}

void Logger::error(const std::string& message, const std::string& task) {
    std::print("{}[ {}ERROR/{} {}]{} {}\n", color.gray, color.red, task, color.gray, color.reset, message);
}

void Logger::warning(const std::string& message, const std::string& task) {
    std::print("{}[ {}WARNING/{} {}]{} {}\n", color.gray, color.yellow, task, color.gray, color.reset, message);
}
