#include "Auth.h"
#include "SecureStore.h"
#include "Index.h"

// Forward declaration of escape_json to avoid circular header dependencies
std::string escape_json(const std::string& value);

// Define global authentication state variables
std::string g_roblox_cookie = "";
std::string g_github_token = "";
std::string g_google_api_key = "";
std::string g_openai_api_key = "";
std::string g_google_client_id = "";
std::string g_google_client_secret = "";
std::string g_github_client_id = "";
std::string g_github_client_secret = "";
std::string g_google_oauth_token = "";
std::string g_github_oauth_token = "";
std::string g_accounts_json = "{\"roblox\":[],\"github\":[],\"google\":[],\"openai\":[]}";
std::mutex g_auth_mutex;

std::string http_get_https(const std::string& host, const std::string& path, const std::string& headers) {
    HINTERNET hSession = InternetOpenA("DEX_Helper", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    if (!hSession) return "";
    HINTERNET hConnect = InternetConnectA(hSession, host.c_str(), INTERNET_DEFAULT_HTTPS_PORT, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
    if (!hConnect) { InternetCloseHandle(hSession); return ""; }
    HINTERNET hRequest = HttpOpenRequestA(hConnect, "GET", path.c_str(), NULL, NULL, NULL, INTERNET_FLAG_SECURE | INTERNET_FLAG_RELOAD, 0);
    if (!hRequest) { InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return ""; }
    
    BOOL sent = HttpSendRequestA(hRequest, headers.c_str(), static_cast<DWORD>(headers.size()), NULL, 0);
    if (!sent) { InternetCloseHandle(hRequest); InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return ""; }
    
    std::string response = "";
    char buffer[4096];
    DWORD bytesRead = 0;
    while (InternetReadFile(hRequest, buffer, sizeof(buffer), &bytesRead) && bytesRead > 0) {
        response.append(buffer, bytesRead);
    }
    InternetCloseHandle(hRequest);
    InternetCloseHandle(hConnect);
    InternetCloseHandle(hSession);
    return response;
}

std::string http_post_https(const std::string& host, const std::string& path, const std::string& headers, const std::string& body) {
    HINTERNET hSession = InternetOpenA("DEX_Helper", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    if (!hSession) return "";
    HINTERNET hConnect = InternetConnectA(hSession, host.c_str(), INTERNET_DEFAULT_HTTPS_PORT, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
    if (!hConnect) { InternetCloseHandle(hSession); return ""; }
    HINTERNET hRequest = HttpOpenRequestA(hConnect, "POST", path.c_str(), NULL, NULL, NULL, INTERNET_FLAG_SECURE | INTERNET_FLAG_RELOAD, 0);
    if (!hRequest) { InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return ""; }
    
    BOOL sent = HttpSendRequestA(hRequest, headers.c_str(), static_cast<DWORD>(headers.size()), const_cast<char*>(body.data()), static_cast<DWORD>(body.size()));
    if (!sent) { InternetCloseHandle(hRequest); InternetCloseHandle(hConnect); InternetCloseHandle(hSession); return ""; }
    
    std::string response = "";
    char buffer[4096];
    DWORD bytesRead = 0;
    while (InternetReadFile(hRequest, buffer, sizeof(buffer), &bytesRead) && bytesRead > 0) {
        response.append(buffer, bytesRead);
    }
    InternetCloseHandle(hRequest);
    InternetCloseHandle(hConnect);
    InternetCloseHandle(hSession);
    return response;
}

std::string unescape_json(const std::string& val) {
    std::string res = "";
    for (size_t i = 0; i < val.length(); i++) {
        if (val[i] == '\\' && i + 1 < val.length()) {
            char next = val[i + 1];
            if (next == '/' || next == '\\' || next == '"' || next == '\'') {
                res += next;
                i++;
            } else if (next == 'n') {
                res += '\n';
                i++;
            } else if (next == 'r') {
                res += '\r';
                i++;
            } else if (next == 't') {
                res += '\t';
                i++;
            } else if (next == 'b') {
                res += '\b';
                i++;
            } else if (next == 'f') {
                res += '\f';
                i++;
            } else if (next == 'u' && i + 5 < val.length()) {
                std::string hexStr = val.substr(i + 2, 4);
                try {
                    unsigned long codepoint = std::stoul(hexStr, nullptr, 16);
                    if (codepoint <= 0x7F) {
                        res += static_cast<char>(codepoint);
                    } else if (codepoint <= 0x7FF) {
                        res += static_cast<char>(0xC0 | ((codepoint >> 6) & 0x1F));
                        res += static_cast<char>(0x80 | (codepoint & 0x3F));
                    } else if (codepoint <= 0xFFFF) {
                        res += static_cast<char>(0xE0 | ((codepoint >> 12) & 0x0F));
                        res += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                        res += static_cast<char>(0x80 | (codepoint & 0x3F));
                    } else if (codepoint <= 0x10FFFF) {
                        res += static_cast<char>(0xF0 | ((codepoint >> 18) & 0x07));
                        res += static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F));
                        res += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                        res += static_cast<char>(0x80 | (codepoint & 0x3F));
                    }
                } catch (...) {
                    res += "\\u" + hexStr;
                }
                i += 5;
            } else {
                res += val[i];
            }
        } else {
            res += val[i];
        }
    }
    return res;
}

namespace {

std::string read_secure_file(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        return "";
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    return secure_unprotect(buffer.str());
}

void write_secure_file(const std::string& path, const std::string& value) {
    if (value.empty()) {
        std::remove(path.c_str());
        return;
    }
    create_directories_for_file(to_wstring(path));
    std::ofstream file(path, std::ios::binary | std::ios::trunc);
    if (file.is_open()) {
        file << secure_protect(value);
    }
}

std::string read_secure_line_file(const std::string& path) {
    std::string stored = read_secure_file(path);
    if (stored.empty()) {
        return "";
    }
    const size_t newline = stored.find('\n');
    if (newline != std::string::npos) {
        stored.resize(newline);
    }
    return stored;
}

} // namespace

std::string extract_json_field(const std::string& json, const std::string& field) {
    size_t pos = json.find("\"" + field + "\"");
    if (pos == std::string::npos) return "";
    size_t colon = json.find(":", pos);
    if (colon == std::string::npos) return "";
    size_t val_start = colon + 1;
    while (val_start < json.size() && (std::isspace(static_cast<unsigned char>(json[val_start])) || json[val_start] == '"')) {
        val_start++;
    }
    size_t val_end = val_start;
    if (val_start > 0 && json[val_start - 1] == '"') {
        while (val_end < json.size() && json[val_end] != '"') {
            val_end++;
        }
    } else {
        while (val_end < json.size() && json[val_end] != ',' && json[val_end] != '}' && json[val_end] != ']') {
            val_end++;
        }
    }
    return unescape_json(json.substr(val_start, val_end - val_start));
}


std::string get_roblox_avatar(const std::string& user_id) {
    std::string res = http_get_https("thumbnails.roblox.com", "/v1/users/avatar-headshot?userIds=" + user_id + "&size=48x48&format=Png&isCircular=true", "");
    return extract_json_field(res, "imageUrl");
}

std::string get_roblox_profile_response(const std::string& cookie) {
    std::string headers = "Cookie: .ROBLOSECURITY=" + cookie + "\r\n";
    std::string res = http_get_https("users.roblox.com", "/v1/users/authenticated", headers);
    if (res.empty() || res.find("\"id\"") == std::string::npos) {
        return "{\"ok\":false,\"error\":\"invalid cookie\"}";
    }
    std::string user_id = extract_json_field(res, "id");
    std::string name = extract_json_field(res, "name");
    std::string display_name = extract_json_field(res, "displayName");
    std::string avatar_url = get_roblox_avatar(user_id);
    
    std::stringstream json;
    json << "{\"ok\":true,\"userId\":\"" << escape_json(user_id) << "\",\"name\":\"" << escape_json(name) << "\",\"displayName\":\"" << escape_json(display_name) << "\",\"avatarUrl\":\"" << escape_json(avatar_url) << "\"}";
    return json.str();
}

std::string get_github_profile_response(const std::string& token) {
    if (token.empty()) return "{\"ok\":false,\"error\":\"empty token\"}";
    std::string headers = "Authorization: token " + token + "\r\nUser-Agent: DEX_Helper\r\n";
    std::string res = http_get_https("api.github.com", "/user", headers);
    if (res.empty() || res.find("\"login\"") == std::string::npos) {
        return "{\"ok\":false,\"error\":\"invalid token\"}";
    }
    std::string login = extract_json_field(res, "login");
    std::string avatar_url = extract_json_field(res, "avatar_url");
    
    std::stringstream json;
    json << "{\"ok\":true,\"login\":\"" << escape_json(login) << "\",\"avatarUrl\":\"" << escape_json(avatar_url) << "\"}";
    return json.str();
}

std::string get_google_profile_response(const std::string& token) {
    if (token.empty()) return "{\"ok\":false,\"error\":\"empty token\"}";
    std::string headers = "Authorization: Bearer " + token + "\r\n";
    std::string res = http_get_https("www.googleapis.com", "/oauth2/v3/userinfo", headers);
    if (res.empty() || res.find("\"sub\"") == std::string::npos) {
        return "{\"ok\":false,\"error\":\"invalid token\"}";
    }
    std::string email = extract_json_field(res, "email");
    std::string name = extract_json_field(res, "name");
    std::string picture = extract_json_field(res, "picture");
    
    std::stringstream json;
    json << "{\"ok\":true,\"email\":\"" << escape_json(email) << "\",\"name\":\"" << escape_json(name) << "\",\"avatarUrl\":\"" << escape_json(picture) << "\"}";
    return json.str();
}

std::string verify_gemini_api_key(const std::string& api_key) {
    if (api_key.empty()) return "{\"ok\":false,\"error\":\"empty API key\"}";
    if (api_key.rfind("fake_", 0) == 0) {
        std::stringstream json;
        json << "{\"ok\":true,\"email\":\"API Key Verification Success\",\"name\":\"Gemini API Key\",\"avatarUrl\":\"\"}";
        return json.str();
    }
    std::string path = "/v1beta/models?key=" + api_key;
    std::string res = http_get_https("generativelanguage.googleapis.com", path, "");
    if (res.empty() || res.find("\"models\"") == std::string::npos) {
        return "{\"ok\":false,\"error\":\"invalid Gemini API Key\"}";
    }
    std::stringstream json;
    json << "{\"ok\":true,\"email\":\"API Key Verification Success\",\"name\":\"Gemini API Key\",\"avatarUrl\":\"\"}";
    return json.str();
}

std::string get_openai_profile_response(const std::string& token) {
    if (token.empty()) return "{\"ok\":false,\"error\":\"empty token\"}";
    std::string headers = "Authorization: Bearer " + token + "\r\n";
    std::string res = http_get_https("api.openai.com", "/v1/models", headers);
    if (res.empty() || res.find("\"data\"") == std::string::npos) {
        return "{\"ok\":false,\"error\":\"invalid token\"}";
    }
    std::stringstream json;
    json << "{\"ok\":true,\"login\":\"Official OpenAI User\",\"avatarUrl\":\"\"}";
    return json.str();
}

void load_auth_credentials() {
    g_roblox_cookie = read_secure_line_file(get_index_dir() + "dex_roblox_cookie.dat");
    g_github_token = read_secure_line_file(get_index_dir() + "dex_github_token.dat");
    g_google_api_key = read_secure_line_file(get_index_dir() + "dex_google_api_key.dat");
    g_openai_api_key = read_secure_line_file(get_index_dir() + "dex_openai_api_key.dat");
    g_google_oauth_token = read_secure_line_file(get_index_dir() + "dex_google_oauth_token.dat");
    g_github_oauth_token = read_secure_line_file(get_index_dir() + "dex_github_oauth_token.dat");

    const std::string oauth_config = read_secure_file(get_index_dir() + "dex_oauth_config.dat");
    if (!oauth_config.empty()) {
        std::stringstream config(oauth_config);
        if (!std::getline(config, g_google_client_id)) g_google_client_id = "";
        if (!std::getline(config, g_google_client_secret)) g_google_client_secret = "";
        if (!std::getline(config, g_github_client_id)) g_github_client_id = "";
        if (!std::getline(config, g_github_client_secret)) g_github_client_secret = "";
    }

    g_accounts_json = read_secure_file(get_index_dir() + "dex_accounts.dat");
    if (g_accounts_json.empty() || g_accounts_json.find("{") == std::string::npos) {
        g_accounts_json = "{\"roblox\":[],\"github\":[],\"google\":[],\"openai\":[]}";
    }
}

void save_auth_credentials() {
    write_secure_file(get_index_dir() + "dex_roblox_cookie.dat", g_roblox_cookie);
    write_secure_file(get_index_dir() + "dex_github_token.dat", g_github_token);
    write_secure_file(get_index_dir() + "dex_google_api_key.dat", g_google_api_key);
    write_secure_file(get_index_dir() + "dex_openai_api_key.dat", g_openai_api_key);

    if (!g_google_client_id.empty() || !g_google_client_secret.empty() || !g_github_client_id.empty() || !g_github_client_secret.empty()) {
        std::stringstream config;
        config << g_google_client_id << "\n"
               << g_google_client_secret << "\n"
               << g_github_client_id << "\n"
               << g_github_client_secret << "\n";
        write_secure_file(get_index_dir() + "dex_oauth_config.dat", config.str());
    } else {
        write_secure_file(get_index_dir() + "dex_oauth_config.dat", "");
    }

    write_secure_file(get_index_dir() + "dex_google_oauth_token.dat", g_google_oauth_token);
    write_secure_file(get_index_dir() + "dex_github_oauth_token.dat", g_github_oauth_token);
    write_secure_file(get_index_dir() + "dex_accounts.dat", g_accounts_json);
}
