#include "configparse.h"
#include "cJSON/cJSON.h"
#include <stdexcept>
#include <iostream>

#include "logger.hpp"

std::vector<std::string> extractStringArray(const cJSON* jsonArray) {
    std::vector<std::string> result;

    if(!jsonArray || !cJSON_IsArray(jsonArray))
        return result;

    const cJSON* item = nullptr;
    cJSON_ArrayForEach(item, jsonArray) {
        if(cJSON_IsString(item) && item->valuestring)
            result.emplace_back(item->valuestring);
    }

    return result;
}

std::string getStringValue(const cJSON* json, const char* key) {
    if(const cJSON* item = cJSON_GetObjectItemCaseSensitive(json, key); cJSON_IsString(item) && item->valuestring)
        return {item->valuestring};

    return "";
}

ConfigParse::Config ConfigParse::parseConfig(const std::string& jsonString) {
    Config config;

    cJSON* json = cJSON_Parse(jsonString.c_str());
    if(!json) {
        const char* error_ptr = cJSON_GetErrorPtr();
        std::string error_msg = "JSON Parse Error";

        if(error_ptr)
            error_msg += ": " + std::string(error_ptr);

        throw std::runtime_error(error_msg);
    }

    try {
        const cJSON* compilers = cJSON_GetObjectItemCaseSensitive(json, "compilers");
        const cJSON* flags = cJSON_GetObjectItemCaseSensitive(json, "flags");
        const cJSON* sources = cJSON_GetObjectItemCaseSensitive(json, "sources");
        const cJSON* include = cJSON_GetObjectItemCaseSensitive(json, "include");
        const cJSON* dependencies = cJSON_GetObjectItemCaseSensitive(json, "dependencies");
        const cJSON* find_pkg = cJSON_GetObjectItemCaseSensitive(json, "find-pkg");
        const std::string velux = getStringValue(json, "velux");
        const std::string language = getStringValue(json, "language");
        const std::string version = getStringValue(json, "version");
        const std::string output = getStringValue(json, "output");
        const std::string type = getStringValue(json, "type");

        config.velux = velux;
        config.language = language;
        config.version = version;
        config.output = output;
        config.type = type;
        config.compilers = extractStringArray(compilers);
        config.flags = extractStringArray(flags);
        config.sources = extractStringArray(sources);
        config.include = extractStringArray(include);
        config.dependencies = extractStringArray(dependencies);
        config.find_pkg = extractStringArray(find_pkg);
    } catch(const std::exception& ex) {
        Logger::error(ex.what(), "Parser");
        cJSON_Delete(json);
        throw;
    }

    cJSON_Delete(json);
    return config;
}

ConfigParse::Config ConfigParse::parseConfigFromFile(const std::string& filename) {
    FILE* file = fopen(filename.c_str(), "r");
    if(!file)
        throw std::runtime_error("Could not open config file: " + filename);

    fseek(file, 0, SEEK_END);
    const long fileSize = ftell(file);
    fseek(file, 0, SEEK_SET);

    std::string content(fileSize, '\0');
    const size_t bytesRead = fread(&content[0], 1, fileSize, file);
    fclose(file);

    if(bytesRead != static_cast<size_t>(fileSize))
        throw std::runtime_error("Error reading config file: " + filename);

    return parseConfig(content);
}
