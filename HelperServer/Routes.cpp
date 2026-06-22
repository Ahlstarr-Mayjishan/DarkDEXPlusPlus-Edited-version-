#include "Routes.h"

#include "Auth.h"
#include "Dashboard.h"
#include "Decompiler.h"
#include "HttpUtil.h"
#include "Index.h"
#include "Toolchain.h"
#include "Win32App.h"

extern ULONGLONG g_last_mcp_time;
extern std::mutex g_log_mutex;

static std::string get_sync_dir() {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return "..\\workspace_sync\\";
    }
    return "workspace_sync\\";
}

static std::wstring get_sync_dir_w() {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return L"..\\workspace_sync";
    }
    return L"workspace_sync";
}

static std::wstring get_sync_path_w(const std::wstring& relative_path) {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return L"..\\workspace_sync\\" + relative_path;
    }
    return L"workspace_sync\\" + relative_path;
}

static size_t find_header_case_insensitive(const std::string& request, const std::string& header_name) {
    std::string lower_request = lower_copy(request);
    std::string lower_header = lower_copy(header_name);
    return lower_request.find(lower_header);
}

static long long get_request_place_id(const std::string& request_headers) {
    size_t pos = find_header_case_insensitive(request_headers, "x-place-id:");
    if (pos == std::string::npos) return 0;
    size_t end = request_headers.find("\r\n", pos);
    if (end == std::string::npos) end = request_headers.size();
    std::string val_str = trim_copy(request_headers.substr(pos + 11, end - (pos + 11)));
    try {
        return std::stoll(val_str);
    } catch (...) {
        return 0;
    }
}

RouteDispatchResult dispatch_http_routes(
    SOCKET client_socket,
    const std::string& method,
    const std::string& path,
    const std::string& body,
    const std::string& request_data
) {
        if ((path == "/" || path == "/app") && method == "GET") {
            send_response(client_socket, 200, "OK", helper_dashboard_html(), "text/html; charset=utf-8");
            return RouteDispatchResult::Handled;
        } else if (path == "/status" && method == "GET") {
            send_response(client_socket, 200, "OK", "DEX++ C++ Helper Server Active");
            return RouteDispatchResult::Handled;
        } else if (path == "/worker-status" && method == "GET") {
            send_response(client_socket, 200, "OK", worker_status(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/toolchain-status" && method == "GET") {
            send_response(client_socket, 200, "OK", toolchain_status(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/open-toolchain-setup" && method == "POST") {
            send_response(client_socket, 200, "OK", open_toolchain_setup(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/script-status" && method == "GET") {
            send_response(client_socket, 200, "OK", script_status_response(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/script" && method == "GET") {
            std::ifstream script_file("DEX++_compiled.luau");
            if (!script_file.is_open()) {
                script_file.open("../DEX++_compiled.luau");
            }
            if (script_file.is_open()) {
                std::stringstream buffer;
                buffer << script_file.rdbuf();
                script_file.close();
                send_response(client_socket, 200, "OK", buffer.str());
            } else {
                send_response(client_socket, 404, "Not Found", "-- Error: DEX++_compiled.luau not found on server.");
            }
            return RouteDispatchResult::Handled;
        } else if (path == "/log" && method == "POST") {
            if (body.size() > MAX_LOG_BODY_SIZE) {
                send_response(client_socket, 413, "Payload Too Large", "Log entry is too large.");
                close_client(client_socket);
                return RouteDispatchResult::CloseConnection;
            }
            std::lock_guard<std::mutex> lock(g_log_mutex);
            std::string log_path = get_index_dir() + "dex_server_logs.txt";
            rotate_log_if_needed(log_path.c_str());
            create_directories_for_file(to_wstring(log_path));
            std::ofstream log_file(log_path.c_str(), std::ios::app);
            if (log_file.is_open()) {
                log_file << body << std::endl;
                log_file.close();
            }
            send_response(client_socket, 200, "OK", "Logged");
            return RouteDispatchResult::Handled;
        } else if ((path == "/normalize-source" || path == "/deobfuscate") && method == "POST") {
            send_response(client_socket, 200, "OK", normalize_source(body));
            return RouteDispatchResult::Handled;
        } else if (path == "/analyze-source" && method == "POST") {
            send_response(client_socket, 200, "OK", analyze_source(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/analyze-source-fast" && method == "POST") {
            send_response(client_socket, 200, "OK", analyze_source_fast(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/analyze-source-deep" && method == "POST") {
            send_response(client_socket, 200, "OK", analyze_source_deep(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/analyze-source-auto" && method == "POST") {
            send_response(client_socket, 200, "OK", analyze_source_auto(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/analyze-remotes" && method == "POST") {
            send_response(client_socket, 200, "OK", analyze_remote_logs(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/index-source" && method == "POST") {
            long long place_id = get_request_place_id(request_data);
            send_response(client_socket, 200, "OK", index_source_payload(body, place_id));
            return RouteDispatchResult::Handled;
        } else if (path == "/search-source" && method == "POST") {
            long long place_id = get_request_place_id(request_data);
            send_response(client_socket, 200, "OK", search_index(body, place_id));
            return RouteDispatchResult::Handled;
        } else if (path == "/index-entry" && method == "POST") {
            long long place_id = get_request_place_id(request_data);
            send_response(client_socket, 200, "OK", index_entry(body, place_id), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/index-status" && method == "GET") {
            long long place_id = get_request_place_id(request_data);
            send_response(client_socket, 200, "OK", index_status(place_id));
            return RouteDispatchResult::Handled;
        } else if (path == "/tool-state" && method == "GET") {
            send_response(client_socket, 200, "OK", get_tool_state_response(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/tool-state" && method == "POST") {
            send_response(client_socket, 200, "OK", set_tool_state_response(body), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/index-save" && method == "POST") {
            send_response(client_socket, 200, "OK", save_index_response());
            return RouteDispatchResult::Handled;
        } else if (path == "/index-load" && method == "POST") {
            send_response(client_socket, 200, "OK", load_index_response());
            return RouteDispatchResult::Handled;
        } else if (path == "/index-clear" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_script_index_mutex);
            long long place_id = get_request_place_id(request_data);
            clear_db_for_place(place_id);
            for (auto it = g_script_index.begin(); it != g_script_index.end(); ) {
                if (it->second.place_id == place_id) {
                    it = g_script_index.erase(it);
                } else {
                    ++it;
                }
            }
            send_response(client_socket, 200, "OK", "{\"ok\":true,\"total\":0,\"persisted\":true}");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/roblox/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_roblox_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_roblox_cookie = body;
                save_auth_credentials();
            }
            send_response(client_socket, 200, "OK", res, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/roblox/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_roblox_cookie = "";
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/roblox/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(client_socket, 200, "OK", get_roblox_profile_response(g_roblox_cookie), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/github/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_github_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_github_token = body;
                g_github_oauth_token = "";
                save_auth_credentials();
            }
            send_response(client_socket, 200, "OK", res, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/github/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_github_token = "";
            g_github_oauth_token = "";
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/github/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            if (!g_github_oauth_token.empty()) {
                send_response(client_socket, 200, "OK", get_github_profile_response(g_github_oauth_token), "application/json");
            } else {
                send_response(client_socket, 200, "OK", get_github_profile_response(g_github_token), "application/json");
            }
            return RouteDispatchResult::Handled;
        } else if (path == "/api/google/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = verify_gemini_api_key(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_google_api_key = body;
                g_google_oauth_token = "";
                save_auth_credentials();
            }
            send_response(client_socket, 200, "OK", res, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/google/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_google_api_key = "";
            g_google_oauth_token = "";
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/google/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            if (!g_google_oauth_token.empty()) {
                send_response(client_socket, 200, "OK", get_google_profile_response(g_google_oauth_token), "application/json");
            } else {
                send_response(client_socket, 200, "OK", verify_gemini_api_key(g_google_api_key), "application/json");
            }
            return RouteDispatchResult::Handled;
        } else if (path == "/api/openai/login" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = get_openai_profile_response(body);
            if (res.find("\"ok\":true") != std::string::npos) {
                g_openai_api_key = body;
                save_auth_credentials();
            }
            send_response(client_socket, 200, "OK", res, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/openai/logout" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_openai_api_key = "";
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/openai/profile" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(client_socket, 200, "OK", get_openai_profile_response(g_openai_api_key), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/accounts" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            send_response(client_socket, 200, "OK", g_accounts_json, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/detect-ides" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            bool mcp_active = (g_last_mcp_time > 0 && (GetTickCount64() - g_last_mcp_time) < 30000);
            std::stringstream json;
            json << "{\"ok\":true,\"ides\":" << detect_running_ides_json() << ",\"mcpActive\":" << (mcp_active ? "true" : "false") << "}";
            send_response(client_socket, 200, "OK", json.str(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/mcp/start" && (method == "POST" || method == "GET")) {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string res = start_mcp_bridger();
            send_response(client_socket, 200, "OK", res, "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/accounts" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_accounts_json = body;
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/auth/active-token" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::string provider = extract_json_field(body, "provider");
            std::string token = extract_json_field(body, "token");
            std::string type = extract_json_field(body, "type");
            
            if (provider == "roblox") {
                g_roblox_cookie = token;
            } else if (provider == "github") {
                if (type == "oauth") {
                    g_github_oauth_token = token;
                    g_github_token = "";
                } else {
                    g_github_token = token;
                    g_github_oauth_token = "";
                }
            } else if (provider == "google") {
                if (type == "oauth") {
                    g_google_oauth_token = token;
                    g_google_api_key = "";
                } else {
                    g_google_api_key = token;
                    g_google_oauth_token = "";
                }
            } else if (provider == "openai") {
                g_openai_api_key = token;
            }
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/auth/oauth-config" && method == "POST") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            g_google_client_id = extract_json_field(body, "googleClientId");
            g_google_client_secret = extract_json_field(body, "googleClientSecret");
            g_github_client_id = extract_json_field(body, "githubClientId");
            g_github_client_secret = extract_json_field(body, "githubClientSecret");
            save_auth_credentials();
            send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/auth/oauth-config" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::stringstream json;
            json << "{\"googleClientId\":\"" << escape_json(g_google_client_id) << "\","
                 << "\"googleClientSecret\":\"" << escape_json(g_google_client_secret) << "\","
                 << "\"githubClientId\":\"" << escape_json(g_github_client_id) << "\","
                 << "\"githubClientSecret\":\"" << escape_json(g_github_client_secret) << "\"}";
            send_response(client_socket, 200, "OK", json.str(), "application/json");
            return RouteDispatchResult::Handled;
        } else if (path == "/api/auth/google/login" && method == "GET") {
            if (g_google_client_id.empty()) {
                send_response(client_socket, 400, "Bad Request", "{\"ok\":false,\"error\":\"Google OAuth is not configured in Developer settings.\"}");
                return RouteDispatchResult::CloseConnection;
            }
            std::stringstream redirect;
            redirect << "https://accounts.google.com/o/oauth2/v2/auth?"
                     << "client_id=" << g_google_client_id
                     << "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgoogle%2Fcallback"
                     << "&response_type=code"
                     << "&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fgenerative-language%20email%20profile"
                     << "&access_type=offline"
                     << "&prompt=consent";
            
            std::stringstream response;
            response << "HTTP/1.1 302 Found\r\n"
                     << "Location: " << redirect.str() << "\r\n"
                     << "Content-Length: 0\r\n\r\n";
            send(client_socket, response.str().data(), static_cast<int>(response.str().size()), 0);
            return RouteDispatchResult::CloseConnection;
        } else if (path == "/api/auth/google/callback" && method == "GET") {
            size_t code_pos = request_data.find("code=");
            if (code_pos == std::string::npos) {
                send_response(client_socket, 400, "Bad Request", "Authentication failed: no code returned.");
                return RouteDispatchResult::CloseConnection;
            }
            size_t amp_pos = request_data.find("&", code_pos);
            size_t space_pos = request_data.find(" ", code_pos);
            size_t end_pos = (amp_pos != std::string::npos && amp_pos < space_pos) ? amp_pos : space_pos;
            std::string auth_code = request_data.substr(code_pos + 5, end_pos - (code_pos + 5));
            
            std::string body = "code=" + auth_code +
                               "&client_id=" + g_google_client_id +
                               "&client_secret=" + g_google_client_secret +
                               "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgoogle%2Fcallback" +
                               "&grant_type=authorization_code";
                               
            std::string res = http_post_https("oauth2.googleapis.com", "/token", "Content-Type: application/x-www-form-urlencoded\r\n", body);
            std::string access_token = extract_json_field(res, "access_token");
            if (access_token.empty()) {
                send_response(client_socket, 400, "Bad Request", "Exchange failed: " + res);
                return RouteDispatchResult::CloseConnection;
            }
            
            {
                std::lock_guard<std::mutex> lock(g_auth_mutex);
                g_google_oauth_token = access_token;
                g_google_api_key = "";
                save_auth_credentials();
            }
            
            std::string success_html = "<html><head><title>Success</title><style>body{background:#0b0e14;color:#cbd5e1;font-family:sans-serif;text-align:center;padding:50px}h1{color:#52b69a}</style></head><body><h1>Login Successful!</h1><p>Google Account successfully connected to DEX++. You can close this tab now.</p><script>window.close()</script></body></html>";
            send_response(client_socket, 200, "OK", success_html, "text/html");
            return RouteDispatchResult::CloseConnection;
        } else if (path == "/api/auth/github/login" && method == "GET") {
            if (g_github_client_id.empty()) {
                send_response(client_socket, 400, "Bad Request", "{\"ok\":false,\"error\":\"GitHub OAuth is not configured.\"}");
                return RouteDispatchResult::CloseConnection;
            }
            std::stringstream redirect;
            redirect << "https://github.com/login/oauth/authorize?"
                     << "client_id=" << g_github_client_id
                     << "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgithub%2Fcallback"
                     << "&scope=repo";
            
            std::stringstream response;
            response << "HTTP/1.1 302 Found\r\n"
                     << "Location: " << redirect.str() << "\r\n"
                     << "Content-Length: 0\r\n\r\n";
            send(client_socket, response.str().data(), static_cast<int>(response.str().size()), 0);
            return RouteDispatchResult::CloseConnection;
        } else if (path == "/api/auth/github/callback" && method == "GET") {
            size_t code_pos = request_data.find("code=");
            if (code_pos == std::string::npos) {
                send_response(client_socket, 400, "Bad Request", "Authentication failed: no code returned.");
                return RouteDispatchResult::CloseConnection;
            }
            size_t amp_pos = request_data.find("&", code_pos);
            size_t space_pos = request_data.find(" ", code_pos);
            size_t end_pos = (amp_pos != std::string::npos && amp_pos < space_pos) ? amp_pos : space_pos;
            std::string auth_code = request_data.substr(code_pos + 5, end_pos - (code_pos + 5));
            
            std::string body = "client_id=" + g_github_client_id +
                               "&client_secret=" + g_github_client_secret +
                               "&code=" + auth_code +
                               "&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fapi%2Fauth%2Fgithub%2Fcallback";
                               
            std::string res = http_post_https("github.com", "/login/oauth/access_token", "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\n", body);
            std::string access_token = extract_json_field(res, "access_token");
            if (access_token.empty()) {
                send_response(client_socket, 400, "Bad Request", "Exchange failed: " + res);
                return RouteDispatchResult::CloseConnection;
            }
            
            {
                std::lock_guard<std::mutex> lock(g_auth_mutex);
                g_github_oauth_token = access_token;
                g_github_token = "";
                save_auth_credentials();
            }
            
            std::string success_html = "<html><head><title>Success</title><style>body{background:#0b0e14;color:#cbd5e1;font-family:sans-serif;text-align:center;padding:50px}h1{color:#52b69a}</style></head><body><h1>Login Successful!</h1><p>GitHub Account successfully connected to DEX++. You can close this tab now.</p><script>window.close()</script></body></html>";
            send_response(client_socket, 200, "OK", success_html, "text/html");
            return RouteDispatchResult::CloseConnection;
        } else if (path == "/api/auth/tokens" && method == "GET") {
            std::lock_guard<std::mutex> lock(g_auth_mutex);
            std::stringstream json;
            json << "{\"ok\":true,"
                 << "\"googleToken\":\"" << escape_json(!g_google_oauth_token.empty() ? g_google_oauth_token : g_google_api_key) << "\","
                 << "\"googleMethod\":\"" << (!g_google_oauth_token.empty() ? "oauth" : "apikey") << "\","
                 << "\"githubToken\":\"" << escape_json(!g_github_oauth_token.empty() ? g_github_oauth_token : g_github_token) << "\","
                 << "\"githubMethod\":\"" << (!g_github_oauth_token.empty() ? "oauth" : "apikey") << "\","
                 << "\"openaiToken\":\"" << escape_json(g_openai_api_key) << "\","
                 << "\"openaiMethod\":\"apikey\","
                 << "\"robloxCookie\":\"" << escape_json(g_roblox_cookie) << "\"}";
            send_response(client_socket, 200, "OK", json.str(), "application/json");
            return RouteDispatchResult::CloseConnection;
        } else if (path == "/stop-local-services" && method == "POST") {
            send_response(client_socket, 200, "OK", "{\"ok\":true,\"stopping\":[\"DEX_Helper.exe\",\"Decompiler.exe\"]}", "application/json");
            schedule_local_shutdown(false);
            return RouteDispatchResult::Handled;
        } else if (path == "/clean-local" && method == "POST") {
            send_response(client_socket, 200, "OK", "{\"ok\":true,\"cleaning\":[\"dex_helper_index.dat\",\"dex_server_logs.txt\"],\"stopping\":[\"DEX_Helper.exe\",\"Decompiler.exe\"]}", "application/json");
            schedule_local_shutdown(true);
            return RouteDispatchResult::Handled;
        } else if (path == "/assign-role" && method == "POST") {
            send_response(client_socket, 200, "OK", assign_role(body));
            return RouteDispatchResult::Handled;
        } else if (path == "/decompile" && method == "POST") {
            send_response(client_socket, 200, "OK", decompile_bytecode(body));
            return RouteDispatchResult::Handled;
        } else if (path == "/sync-to-disk" && method == "POST") {
            auto parts = split_header_payload(body, 1);
            if (parts.size() != 2 || parts[0].empty()) {
                send_response(client_socket, 400, "Bad Request", "{\"ok\":false,\"error\":\"invalid payload\"}", "application/json");
                close_client(client_socket);
                return RouteDispatchResult::CloseConnection;
            }
            
            std::string script_path = parts[0];
            std::string source_code = parts[1];
            
            std::string local_rel = get_sync_dir();
            for (char c : script_path) {
                if (c == '.') {
                    local_rel += '\\';
                } else {
                    local_rel += c;
                }
            }
            local_rel += ".luau";
            
            std::wstring w_path = to_wstring(local_rel);
            create_directories_for_file(w_path);
            
            std::ofstream out(w_path.c_str(), std::ios::binary | std::ios::trunc);
            if (out.is_open()) {
                out.write(source_code.data(), source_code.size());
                out.close();
                send_response(client_socket, 200, "OK", "{\"ok\":true}", "application/json");
            } else {
                send_response(client_socket, 500, "Internal Error", "{\"ok\":false,\"error\":\"could not open file for writing\"}", "application/json");
            }
            return RouteDispatchResult::Handled;
        } else if (path == "/sync-poll" && method == "POST") {
            unsigned long long client_time = 0;
            try {
                client_time = std::stoull(body);
            } catch (...) {
                client_time = 0;
            }
            
            CreateDirectoryW(get_sync_dir_w().c_str(), NULL);
            std::vector<FileInfo> files;
            scan_directory_recursive(get_sync_dir_w(), L"", files);
            
            std::stringstream json;
            json << "{\"ok\":true,\"files\":[";
            bool first_file = true;
            for (const auto& file : files) {
                if (file.last_write_time > client_time) {
                    std::wstring full_w = get_sync_path_w(to_wstring(file.relative_path));
                    std::ifstream in(full_w.c_str(), std::ios::binary);
                    std::string src = "";
                    if (in.is_open()) {
                        std::stringstream buffer;
                        buffer << in.rdbuf();
                        src = buffer.str();
                        in.close();
                    }
                    
                    std::string script_path = "";
                    std::string rel = file.relative_path;
                    if (rel.size() > 5 && rel.substr(rel.size() - 5) == ".luau") {
                        rel = rel.substr(0, rel.size() - 5);
                    }
                    for (char c : rel) {
                        if (c == '\\') {
                            script_path += '.';
                        } else {
                            script_path += c;
                        }
                    }
                    
                    if (!first_file) json << ",";
                    first_file = false;
                    
                    json << "{\"path\":\"" << escape_json(script_path) << "\","
                         << "\"source\":\"" << escape_json(src) << "\","
                         << "\"timestamp\":" << file.last_write_time << "}";
                }
            }
            
            FILETIME current_ft;
            GetSystemTimeAsFileTime(&current_ft);
            ULARGE_INTEGER current_ui;
            current_ui.LowPart = current_ft.dwLowDateTime;
            current_ui.HighPart = current_ft.dwHighDateTime;
            
            json << "],\"timestamp\":" << current_ui.QuadPart << "}";
            send_response(client_socket, 200, "OK", json.str(), "application/json");
            return RouteDispatchResult::Handled;
        }

    return RouteDispatchResult::NotFound;
}
