#include "Index.h"
#include <regex>
#include <shlobj.h>
const char* INDEX_MAGIC = "DEXPP_INDEX_V1";

std::string get_index_dir() {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return "..\\index_data\\";
    }
    return "index_data\\";
}

std::wstring get_index_dir_w() {
    DWORD attrs = GetFileAttributesA("..\\DEX++.luau");
    if (attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return L"..\\index_data";
    }
    return L"index_data";
}

std::string get_db_path() {
    return get_index_dir() + "dex_helper.db";
}

std::string get_index_file_path() {
    return get_index_dir() + "dex_helper_index.dat";
}

std::unordered_map<std::string, IndexedScript> g_script_index;
std::mutex g_script_index_mutex;

std::wstring to_wstring(const std::string& str) {
    return std::wstring(str.begin(), str.end());
}

std::string to_string(const std::wstring& wstr) {
    return std::string(wstr.begin(), wstr.end());
}

void create_directories_for_file(const std::wstring& file_path) {
    size_t pos = 0;
    while ((pos = file_path.find(L'\\', pos)) != std::wstring::npos) {
        if (pos > 0) {
            std::wstring dir = file_path.substr(0, pos);
            CreateDirectoryW(dir.c_str(), NULL);
        }
        pos += 1;
    }
}

void scan_directory_recursive(const std::wstring& base_dir, const std::wstring& current_subdir, std::vector<FileInfo>& files) {
    std::wstring search_path = base_dir + L"\\" + (current_subdir.empty() ? L"" : current_subdir + L"\\") + L"*";
    WIN32_FIND_DATAW find_data;
    HANDLE find_handle = FindFirstFileW(search_path.c_str(), &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) return;
    
    do {
        std::wstring file_name = find_data.cFileName;
        if (file_name == L"." || file_name == L"..") continue;
        
        std::wstring relative_file = current_subdir.empty() ? file_name : current_subdir + L"\\" + file_name;
        
        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            scan_directory_recursive(base_dir, relative_file, files);
        } else {
            ULARGE_INTEGER ft;
            ft.LowPart = find_data.ftLastWriteTime.dwLowDateTime;
            ft.HighPart = find_data.ftLastWriteTime.dwHighDateTime;
            
            std::string rel_str(relative_file.begin(), relative_file.end());
            files.push_back({rel_str, ft.QuadPart});
        }
    } while (FindNextFileW(find_handle, &find_data));
    
    FindClose(find_handle);
}

std::string normalize_source(const std::string& source) {
    std::unordered_map<std::string, std::string> var_map;
    int var_counter = 0;

    auto is_obfuscated = [](const std::string& name) {
        if (name.empty()) return false;
        if (std::isdigit(static_cast<unsigned char>(name[0]))) return false;

        static const std::unordered_set<std::string> reserved = {
            "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
            "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
            "until", "while", "self", "game", "workspace", "script"
        };
        if (reserved.count(name)) return false;

        if (name.rfind("l__u__", 0) == 0 || name.rfind("u_", 0) == 0) return true;
        if (name.rfind("_0x", 0) == 0 || name.rfind("0x", 0) == 0) return true;

        if (name.length() >= 4) {
            bool barcode = true;
            for (char c : name) {
                if (c != 'I' && c != 'l' && c != '1') {
                    barcode = false;
                    break;
                }
            }
            if (barcode) return true;
        }
        return false;
    };

    std::string current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (is_obfuscated(current_word) && var_map.count(current_word) == 0) {
                    var_map[current_word] = "var_" + std::to_string(++var_counter);
                }
                current_word = "";
            }
        }
    }
    if (!current_word.empty() && is_obfuscated(current_word) && var_map.count(current_word) == 0) {
        var_map[current_word] = "var_" + std::to_string(++var_counter);
    }

    std::string result = "";
    current_word = "";
    for (char c : source) {
        if (isalnum(static_cast<unsigned char>(c)) || c == '_') {
            current_word += c;
        } else {
            if (!current_word.empty()) {
                if (var_map.count(current_word)) {
                    result += var_map[current_word];
                } else {
                    result += current_word;
                }
                current_word = "";
            }
            result += c;
        }
    }
    if (!current_word.empty()) {
        if (var_map.count(current_word)) {
            result += var_map[current_word];
        } else {
            result += current_word;
        }
    }

    return result;
}

std::string escape_json(const std::string& value) {
    std::string out;
    out.reserve(value.size() + 16);
    for (char c : value) {
        switch (c) {
        case '\\': out += "\\\\"; break;
        case '"': out += "\\\""; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (static_cast<unsigned char>(c) < 32) {
                out += " ";
            } else {
                out += c;
            }
            break;
        }
    }
    return out;
}

int count_token(const std::string& source, const std::string& token) {
    int count = 0;
    size_t pos = 0;
    while ((pos = source.find(token, pos)) != std::string::npos) {
        ++count;
        pos += token.size();
    }
    return count;
}

std::string lower_copy(const std::string& value) {
    std::string out = value;
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return out;
}

std::string trim_copy(const std::string& value) {
    size_t first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    size_t last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::string make_snippet(const std::string& source, size_t pos) {
    if (source.empty()) return "";
    size_t start = pos > 70 ? pos - 70 : 0;
    size_t end = std::min(source.size(), pos + 150);
    std::string snippet = source.substr(start, end - start);
    for (char& c : snippet) {
        if (c == '\r' || c == '\n' || c == '\t') c = ' ';
    }
    return snippet;
}

std::vector<std::string> split_header_payload(const std::string& body, int header_lines) {
    std::vector<std::string> parts;
    size_t start = 0;
    for (int i = 0; i < header_lines; ++i) {
        size_t pos = body.find('\n', start);
        if (pos == std::string::npos) return {};
        std::string line = body.substr(start, pos - start);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        parts.push_back(line);
        start = pos + 1;
    }
    parts.push_back(body.substr(start));
    return parts;
}

std::vector<std::string> top_identifiers(const std::string& source, int limit) {
    static const std::unordered_set<std::string> reserved = {
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
        "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
        "until", "while", "self", "game", "workspace", "script", "local", "return"
    };
    std::unordered_map<std::string, int> counts;
    std::string word;
    for (char c : source) {
        if (std::isalnum(static_cast<unsigned char>(c)) || c == '_') {
            word += c;
        } else if (!word.empty()) {
            if (word.size() >= 3 && !reserved.count(word)) counts[word]++;
            word.clear();
        }
    }
    if (!word.empty() && word.size() >= 3 && !reserved.count(word)) counts[word]++;

    std::vector<std::pair<std::string, int>> rows(counts.begin(), counts.end());
    std::sort(rows.begin(), rows.end(), [](const auto& a, const auto& b) {
        if (a.second == b.second) return a.first < b.first;
        return a.second > b.second;
    });

    std::vector<std::string> out;
    for (int i = 0; i < static_cast<int>(rows.size()) && i < limit; ++i) {
        out.push_back(rows[i].first + ":" + std::to_string(rows[i].second));
    }
    return out;
}

std::string identifier_name(const std::string& identifier_count) {
    size_t split = identifier_count.find(':');
    if (split == std::string::npos) return identifier_count;
    return identifier_count.substr(0, split);
}

double confidence_for_match(const std::string& match_type, int score) {
    double confidence = 0.60;
    if (match_type == "name") confidence = 0.98;
    else if (match_type == "identifier") confidence = 0.88;
    else if (match_type == "path") confidence = 0.82;
    else if (match_type == "source") confidence = 0.72;
    confidence += std::min(0.08, static_cast<double>(score) / 250.0);
    return std::min(0.99, confidence);
}

std::string analyze_source(const std::string& source) {
    int lines = source.empty() ? 0 : 1;
    for (char c : source) if (c == '\n') ++lines;

    std::vector<std::pair<std::string, int>> signals = {
        {"HttpGet", count_token(source, "HttpGet")},
        {"HttpPost", count_token(source, "HttpPost")},
        {"loadstring", count_token(source, "loadstring")},
        {"require", count_token(source, "require")},
        {"FireServer", count_token(source, "FireServer")},
        {"InvokeServer", count_token(source, "InvokeServer")},
        {"OnClientEvent", count_token(source, "OnClientEvent")},
        {"OnClientInvoke", count_token(source, "OnClientInvoke")},
        {"getgenv", count_token(source, "getgenv")},
        {"getgc", count_token(source, "getgc")},
        {"hookfunction", count_token(source, "hookfunction")},
        {"hookmetamethod", count_token(source, "hookmetamethod")},
    };

    int risky = 0;
    for (const auto& item : signals) {
        if (item.first == "HttpGet" || item.first == "HttpPost" || item.first == "loadstring" ||
            item.first == "getgenv" || item.first == "getgc" || item.first == "hookfunction" ||
            item.first == "hookmetamethod") {
            risky += item.second;
        }
    }

    std::string ast_json = ast_analyze_source(source);

    std::stringstream json;
    json << "{";
    json << "\"ok\":true,";
    json << "\"worker\":\"cxx_core\",";
    json << "\"language\":\"C++\",";
    json << "\"bytes\":" << source.size() << ",";
    json << "\"lines\":" << lines << ",";
    json << "\"functions\":" << count_token(source, "function") << ",";
    json << "\"locals\":" << count_token(source, "local ") << ",";
    json << "\"requires\":" << count_token(source, "require") << ",";
    json << "\"remoteCalls\":" << (count_token(source, "FireServer") + count_token(source, "InvokeServer")) << ",";
    json << "\"riskySignals\":" << risky << ",";
    json << "\"signals\":[";
    bool first = true;
    for (const auto& item : signals) {
        if (item.second <= 0) continue;
        if (!first) json << ",";
        first = false;
        json << "{\"name\":\"" << escape_json(item.first) << "\",\"count\":" << item.second << "}";
    }
    json << "],";
    json << "\"topIdentifiers\":[";
    auto ids = top_identifiers(source, 12);
    for (size_t i = 0; i < ids.size(); ++i) {
        if (i > 0) json << ",";
        json << "\"" << escape_json(ids[i]) << "\"";
    }
    json << "],";
    json << "\"ast\":" << ast_json;
    json << "}";
    return json.str();
}

struct RemoteSummary {
    std::string path;
    int calls = 0;
    int outgoing = 0;
    int incoming = 0;
    std::unordered_map<std::string, int> methods;
    std::vector<std::string> samples;
    int risk = 0;
    std::vector<std::string> flags;
};

void add_remote_flag(RemoteSummary& summary, const std::string& flag, int score) {
    if (std::find(summary.flags.begin(), summary.flags.end(), flag) == summary.flags.end()) {
        summary.flags.push_back(flag);
        summary.risk += score;
    }
}

std::string compact_copy(const std::string& value, size_t limit) {
    std::string out = value;
    std::replace(out.begin(), out.end(), '\r', ' ');
    std::replace(out.begin(), out.end(), '\n', ' ');
    if (out.size() > limit) out = out.substr(0, limit) + "...";
    return out;
}

std::string analyze_remote_logs(const std::string& logs) {
    std::unordered_map<std::string, RemoteSummary> summaries;
    std::unordered_map<std::string, int> method_counts;
    int total = 0;
    int parsed = 0;

    std::stringstream input(logs);
    std::string line;
    while (std::getline(input, line)) {
        line = trim_copy(line);
        if (line.empty()) continue;
        ++total;

        std::string direction = "unknown";
        if (line.find(" outgoing ") != std::string::npos || line.find("] out ") != std::string::npos || line.find("[outgoing]") != std::string::npos) {
            direction = "out";
        } else if (line.find(" incoming ") != std::string::npos || line.find("] in ") != std::string::npos || line.find("[incoming]") != std::string::npos) {
            direction = "in";
        }

        size_t method_pos = line.find(":FireServer()");
        std::string method = "unknown";
        if (method_pos != std::string::npos) {
            method = "FireServer";
        } else {
            method_pos = line.find(":InvokeServer()");
            if (method_pos != std::string::npos) method = "InvokeServer";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Fire()");
            if (method_pos != std::string::npos) method = "Fire";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Invoke()");
            if (method_pos != std::string::npos) method = "Invoke";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":OnClientEvent()");
            if (method_pos != std::string::npos) method = "OnClientEvent";
        }
        if (method_pos == std::string::npos) {
            method_pos = line.find(":Event()");
            if (method_pos != std::string::npos) method = "Event";
        }
        if (method_pos == std::string::npos) continue;

        size_t path_start = line.rfind(' ', method_pos);
        if (path_start == std::string::npos) path_start = line.rfind(']', method_pos);
        path_start = (path_start == std::string::npos) ? 0 : path_start + 1;
        std::string path = trim_copy(line.substr(path_start, method_pos - path_start));
        if (path.empty()) continue;

        std::string args;
        size_t args_pos = line.find('|', method_pos);
        if (args_pos != std::string::npos) args = trim_copy(line.substr(args_pos + 1));

        RemoteSummary& summary = summaries[path];
        if (summary.path.empty()) summary.path = path;
        summary.calls += 1;
        if (direction == "out") summary.outgoing += 1;
        if (direction == "in") summary.incoming += 1;
        summary.methods[method] += 1;
        method_counts[method] += 1;
        if (!args.empty() && summary.samples.size() < 3) summary.samples.push_back(compact_copy(args, 180));
        ++parsed;

        std::string lower = lower_copy(path + " " + args);
        if (lower.find("admin") != std::string::npos || lower.find("ban") != std::string::npos || lower.find("kick") != std::string::npos) {
            add_remote_flag(summary, "admin/control wording", 4);
        }
        if (lower.find("cash") != std::string::npos || lower.find("coin") != std::string::npos || lower.find("money") != std::string::npos || lower.find("gem") != std::string::npos) {
            add_remote_flag(summary, "currency wording", 3);
        }
        if (lower.find("buy") != std::string::npos || lower.find("purchase") != std::string::npos || lower.find("reward") != std::string::npos) {
            add_remote_flag(summary, "transaction/reward wording", 3);
        }
        if (lower.find("teleport") != std::string::npos || lower.find("position") != std::string::npos || lower.find("cframe") != std::string::npos) {
            add_remote_flag(summary, "movement/position wording", 2);
        }
        if (method == "InvokeServer") add_remote_flag(summary, "blocking remote function", 1);
        if (summary.calls >= 30) add_remote_flag(summary, "high frequency", 2);
    }

    std::vector<RemoteSummary*> rows;
    rows.reserve(summaries.size());
    for (auto& item : summaries) rows.push_back(&item.second);
    std::sort(rows.begin(), rows.end(), [](const RemoteSummary* a, const RemoteSummary* b) {
        if (a->risk != b->risk) return a->risk > b->risk;
        return a->calls > b->calls;
    });

    std::stringstream json;
    json << "{\"ok\":true,\"lines\":" << total
         << ",\"parsed\":" << parsed
         << ",\"remotes\":" << rows.size()
         << ",\"methodCounts\":{";
    bool first = true;
    for (const auto& item : method_counts) {
        if (!first) json << ",";
        first = false;
        json << "\"" << escape_json(item.first) << "\":" << item.second;
    }
    json << "},\"results\":[";
    size_t limit = std::min<size_t>(rows.size(), 80);
    for (size_t i = 0; i < limit; ++i) {
        const RemoteSummary& row = *rows[i];
        if (i) json << ",";
        json << "{\"path\":\"" << escape_json(row.path) << "\","
             << "\"calls\":" << row.calls << ","
             << "\"outgoing\":" << row.outgoing << ","
             << "\"incoming\":" << row.incoming << ","
             << "\"risk\":" << row.risk << ",\"methods\":{";
        bool first_method = true;
        for (const auto& method_item : row.methods) {
            if (!first_method) json << ",";
            first_method = false;
            json << "\"" << escape_json(method_item.first) << "\":" << method_item.second;
        }
        json << "},\"flags\":[";
        for (size_t j = 0; j < row.flags.size(); ++j) {
            if (j) json << ",";
            json << "\"" << escape_json(row.flags[j]) << "\"";
        }
        json << "],\"samples\":[";
        for (size_t j = 0; j < row.samples.size(); ++j) {
            if (j) json << ",";
            json << "\"" << escape_json(row.samples[j]) << "\"";
        }
        json << "]}";
    }
    json << "]}";
    return json.str();
}


ScoredRole score_role(const std::string& text, const RoleProfile& profile) {
    ScoredRole result{&profile, 0, {}};
    for (const auto& term : profile.keywords) {
        int hits = count_token(text, term.first);
        if (hits <= 0) continue;
        result.score += hits * term.second;
        if (result.matched.size() < 6) {
            result.matched.push_back(term.first);
        }
    }
    return result;
}

std::string assign_role(const std::string& task) {
    std::string text = lower_copy(task);
    std::vector<RoleProfile> profiles = {
        {
            "cxx_helper_core",
            "C++ Helper Core",
            "C++",
            "HelperServer",
            "Fast indexing, source analysis, cache maintenance, search, and structured export.",
            {
                {"index", 7}, {"search", 7}, {"cache", 7}, {"analysis", 6}, {"analyze", 6},
                {"parse", 5}, {"json", 6}, {"deobfuscate", 8}, {"source", 4}, {"snippet", 4},
                {"timeline", 4}, {"graph", 4}, {"dependency", 4}, {"report", 4}, {"export", 4},
                {"log", 3}, {"token", 4}, {"score", 3}, {"pack", 4}
            }
        },
        {
            "luau_ui",
            "Luau UI / Explorer",
            "Luau",
            "Explorer",
            "Immediate UI work, tree rendering, selection handling, buttons, tabs, and menus.",
            {
                {"ui", 6}, {"window", 6}, {"button", 7}, {"tab", 7}, {"menu", 7},
                {"tree", 8}, {"selection", 8}, {"explorer", 7}, {"panel", 5}, {"label", 4},
                {"textbox", 6}, {"render", 6}, {"layout", 6}, {"context", 5}, {"click", 5},
                {"select", 6}, {"copy", 4}, {"view", 4}
            }
        },
        {
            "luau_runtime",
            "Luau Runtime Monitor",
            "Luau",
            "RuntimeInspector",
            "Live object capture, remotes, property tracking, timeline, and lightweight client state.",
            {
                {"runtime", 8}, {"live", 6}, {"remote", 8}, {"remotes", 8}, {"property", 7},
                {"tracker", 6}, {"timeline", 8}, {"snapshot", 6}, {"capture", 6}, {"monitor", 7},
                {"buffer", 5}, {"record", 5}, {"event", 5}, {"inspector", 7}, {"state", 4}
            }
        },
        {
            "ai_context",
            "AI Context Packager",
            "Mixed",
            "CopyToAI",
            "Prompt building, summary packing, object context, and beginner-friendly explanation.",
            {
                {"ai", 8}, {"prompt", 8}, {"context", 8}, {"copy", 6}, {"summar", 7},
                {"beginner", 5}, {"explain", 5}, {"pack", 5}, {"export", 5}, {"guide", 4}
            }
        }
    };

    std::vector<ScoredRole> scored;
    scored.reserve(profiles.size());
    for (const auto& profile : profiles) {
        scored.push_back(score_role(text, profile));
    }

    std::sort(scored.begin(), scored.end(), [](const ScoredRole& a, const ScoredRole& b) {
        if (a.score == b.score) return a.profile->id < b.profile->id;
        return a.score > b.score;
    });

    const ScoredRole* primary = scored.empty() ? nullptr : &scored[0];
    const ScoredRole* secondary = scored.size() > 1 ? &scored[1] : nullptr;

    auto confidence_for = [](int score) {
        if (score <= 0) return 35;
        return std::min(98, 40 + score * 4);
    };

    std::stringstream json;
    json << "{";
    json << "\"ok\":true,";
    json << "\"taskBytes\":" << task.size() << ",";
    json << "\"primary\":{";
    if (primary) {
        json << "\"role\":\"" << escape_json(primary->profile->id) << "\",";
        json << "\"label\":\"" << escape_json(primary->profile->label) << "\",";
        json << "\"language\":\"" << escape_json(primary->profile->language) << "\",";
        json << "\"module\":\"" << escape_json(primary->profile->module) << "\",";
        json << "\"confidence\":" << confidence_for(primary->score) << ",";
        json << "\"score\":" << primary->score << ",";
        json << "\"summary\":\"" << escape_json(primary->profile->summary) << "\",";
        json << "\"signals\":[";
        for (size_t i = 0; i < primary->matched.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(primary->matched[i]) << "\"";
        }
        json << "]";
    } else {
        json << "\"role\":\"unknown\",\"label\":\"Unknown\",\"language\":\"Unknown\",\"module\":\"Unknown\",\"confidence\":35,\"score\":0,\"summary\":\"No match\",\"signals\":[]";
    }
    json << "},";
    json << "\"secondary\":{";
    if (secondary) {
        json << "\"role\":\"" << escape_json(secondary->profile->id) << "\",";
        json << "\"label\":\"" << escape_json(secondary->profile->label) << "\",";
        json << "\"language\":\"" << escape_json(secondary->profile->language) << "\",";
        json << "\"module\":\"" << escape_json(secondary->profile->module) << "\",";
        json << "\"confidence\":" << confidence_for(secondary->score) << ",";
        json << "\"score\":" << secondary->score << ",";
        json << "\"summary\":\"" << escape_json(secondary->profile->summary) << "\",";
        json << "\"signals\":[";
        for (size_t i = 0; i < secondary->matched.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(secondary->matched[i]) << "\"";
        }
        json << "]";
    } else {
        json << "\"role\":\"unknown\",\"label\":\"Unknown\",\"language\":\"Unknown\",\"module\":\"Unknown\",\"confidence\":35,\"score\":0,\"summary\":\"No fallback\",\"signals\":[]";
    }
    json << "},";
    json << "\"workflow\":[";
    if (primary) {
        std::vector<std::string> workflow = {
            "Send heavy, repeated, or cached work to " + primary->profile->module + ".",
            "Keep UI, selection, and click handling in Luau.",
            "Use cache-first flows; only fall back when the helper is offline."
        };
        for (size_t i = 0; i < workflow.size(); ++i) {
            if (i > 0) json << ",";
            json << "\"" << escape_json(workflow[i]) << "\"";
        }
    }
    json << "]";
    json << "}";
    return json.str();
}

static std::string sanitize_fts_query(const std::string& query) {
    std::string sanitized = "";
    bool in_word = false;
    for (char c : query) {
        if (std::isalnum(static_cast<unsigned char>(c)) || c == '_') {
            sanitized += c;
            in_word = true;
        } else {
            if (in_word) {
                sanitized += "* ";
                in_word = false;
            }
        }
    }
    if (in_word) {
        sanitized += "*";
    }
    while (!sanitized.empty() && sanitized.back() == ' ') {
        sanitized.pop_back();
    }
    return sanitized;
}

static bool write_script_to_db(const IndexedScript& entry) {
    if (!g_db && !init_db()) {
        std::cerr << "write_script_to_db error: init_db failed" << std::endl;
        return false;
    }

    char* err_msg = nullptr;
    sqlite3_exec(g_db, "BEGIN TRANSACTION;", nullptr, nullptr, &err_msg);
    if (err_msg) {
        std::cerr << "write_script_to_db error: BEGIN failed: " << err_msg << std::endl;
        sqlite3_free(err_msg);
    }

    const char* insert_sql = "INSERT OR REPLACE INTO indexed_scripts (key, place_id, path, name, class_name, source, analysis, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(g_db, insert_sql, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        std::cerr << "write_script_to_db error: prepare insert failed: " << sqlite3_errmsg(g_db) << std::endl;
        sqlite3_exec(g_db, "ROLLBACK;", nullptr, nullptr, nullptr);
        return false;
    }

    sqlite3_bind_text(stmt, 1, entry.key.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 2, entry.place_id);
    sqlite3_bind_text(stmt, 3, entry.path.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, entry.name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 5, entry.class_name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 6, entry.source.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, entry.analysis.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 8, static_cast<sqlite3_int64>(entry.updated_at));

    rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        std::cerr << "write_script_to_db error: step insert failed: " << sqlite3_errmsg(g_db) << std::endl;
        sqlite3_exec(g_db, "ROLLBACK;", nullptr, nullptr, nullptr);
        return false;
    }

    const char* delete_fts = "DELETE FROM indexed_scripts_fts WHERE key = ? AND place_id = ?;";
    sqlite3_stmt* stmt_del = nullptr;
    rc = sqlite3_prepare_v2(g_db, delete_fts, -1, &stmt_del, nullptr);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt_del, 1, entry.key.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt_del, 2, entry.place_id);
        sqlite3_step(stmt_del);
        sqlite3_finalize(stmt_del);
    } else {
        std::cerr << "write_script_to_db warning: prepare delete FTS failed: " << sqlite3_errmsg(g_db) << std::endl;
    }

    const char* insert_fts = "INSERT INTO indexed_scripts_fts (key, place_id, path, name, source) VALUES (?, ?, ?, ?, ?);";
    sqlite3_stmt* stmt_fts = nullptr;
    rc = sqlite3_prepare_v2(g_db, insert_fts, -1, &stmt_fts, nullptr);
    if (rc == SQLITE_OK) {
        sqlite3_bind_text(stmt_fts, 1, entry.key.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt_fts, 2, entry.place_id);
        sqlite3_bind_text(stmt_fts, 3, entry.path.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt_fts, 4, entry.name.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt_fts, 5, entry.source.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_step(stmt_fts);
        sqlite3_finalize(stmt_fts);
    } else {
        std::cerr << "write_script_to_db warning: prepare insert FTS failed: " << sqlite3_errmsg(g_db) << std::endl;
    }

    sqlite3_exec(g_db, "COMMIT;", nullptr, nullptr, nullptr);
    return true;
}

static bool clear_db() {
    if (!g_db && !init_db()) return false;
    char* err_msg = nullptr;
    int rc = sqlite3_exec(g_db, "DELETE FROM indexed_scripts; DELETE FROM indexed_scripts_fts;", nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        std::cerr << "Error clearing db: " << (err_msg ? err_msg : "unknown") << std::endl;
        sqlite3_free(err_msg);
        return false;
    }
    return true;
}

bool clear_db_for_place(long long place_id) {
    if (!g_db && !init_db()) return false;
    
    sqlite3_exec(g_db, "BEGIN TRANSACTION;", nullptr, nullptr, nullptr);
    
    sqlite3_stmt* stmt1 = nullptr;
    sqlite3_prepare_v2(g_db, "DELETE FROM indexed_scripts WHERE place_id = ?;", -1, &stmt1, nullptr);
    if (stmt1) {
        sqlite3_bind_int64(stmt1, 1, place_id);
        sqlite3_step(stmt1);
        sqlite3_finalize(stmt1);
    }
    
    sqlite3_stmt* stmt2 = nullptr;
    sqlite3_prepare_v2(g_db, "DELETE FROM indexed_scripts_fts WHERE place_id = ?;", -1, &stmt2, nullptr);
    if (stmt2) {
        sqlite3_bind_int64(stmt2, 1, place_id);
        sqlite3_step(stmt2);
        sqlite3_finalize(stmt2);
    }
    
    sqlite3_exec(g_db, "COMMIT;", nullptr, nullptr, nullptr);
    return true;
}

std::string index_source_payload(const std::string& body, long long place_id) {
    auto parts = split_header_payload(body, 4);
    if (parts.size() != 5 || parts[0].empty()) {
        return "{\"ok\":false,\"error\":\"invalid index payload\"}";
    }

    IndexedScript entry;
    entry.key = parts[0];
    entry.place_id = place_id;
    entry.path = parts[1];
    entry.name = parts[2];
    entry.class_name = parts[3];
    entry.source = parts[4];
    entry.lower_source = lower_copy(entry.source);
    entry.lower_path = lower_copy(entry.path);
    entry.analysis = analyze_source(entry.source);
    entry.top_identifiers = top_identifiers(entry.source, 12);
    entry.updated_at = std::time(nullptr);
    std::time_t updated_at = entry.updated_at;

    // Write to SQLite database
    bool persisted = write_script_to_db(entry);

    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    std::string map_key = std::to_string(place_id) + "|" + entry.key;
    g_script_index[map_key] = std::move(entry);

    size_t bytes = 0;
    size_t count = 0;
    for (const auto& item : g_script_index) {
        if (item.second.place_id == place_id) {
            bytes += item.second.source.size();
            count++;
        }
    }

    std::stringstream json;
    json << "{\"ok\":true,\"total\":" << count
         << ",\"bytes\":" << bytes
         << ",\"updatedAt\":" << static_cast<long long>(updated_at)
         << ",\"persisted\":" << (persisted ? "true" : "false")
         << "}";
    return json.str();
}

std::string index_status(long long place_id) {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    size_t bytes = 0;
    size_t count = 0;
    std::time_t newest = 0;
    std::time_t oldest = 0;
    bool seen = false;
    for (const auto& item : g_script_index) {
        if (place_id == 0 || item.second.place_id == place_id) {
            bytes += item.second.source.size();
            count++;
            std::time_t updated = item.second.updated_at;
            if (!seen) {
                newest = oldest = updated;
                seen = true;
            } else {
                newest = std::max(newest, updated);
                oldest = std::min(oldest, updated);
            }
        }
    }

    std::stringstream json;
    json << "{\"ok\":true,\"scripts\":" << count
         << ",\"bytes\":" << bytes
         << ",\"oldestUpdatedAt\":" << static_cast<long long>(oldest)
         << ",\"newestUpdatedAt\":" << static_cast<long long>(newest)
         << "}";
    return json.str();
}

enum SearchMode {
    MODE_NORMAL,
    MODE_REGEX,
    MODE_FUZZY
};

struct SearchQuery {
    SearchMode mode = MODE_NORMAL;
    std::string pattern;
};

SearchQuery parse_search_query(const std::string& raw_query) {
    SearchQuery sq;
    sq.pattern = raw_query;
    std::string trimmed = trim_copy(raw_query);
    if (trimmed.rfind("re:", 0) == 0) {
        sq.mode = MODE_REGEX;
        std::string pat = trimmed.substr(3);
        if (pat.size() >= 2 && pat.front() == '"' && pat.back() == '"') {
            sq.pattern = pat.substr(1, pat.size() - 2);
        } else {
            sq.pattern = pat;
        }
    } else if (trimmed.rfind("fuzzy:", 0) == 0) {
        sq.mode = MODE_FUZZY;
        std::string pat = trimmed.substr(6);
        if (pat.size() >= 2 && pat.front() == '"' && pat.back() == '"') {
            sq.pattern = pat.substr(1, pat.size() - 2);
        } else {
            sq.pattern = pat;
        }
    }
    return sq;
}

bool fuzzy_match(const std::string& str, const std::string& pattern, int& out_score) {
    if (pattern.empty()) {
        out_score = 0;
        return true;
    }
    std::string lower_str = lower_copy(str);
    std::string lower_pat = lower_copy(pattern);
    if (lower_str == lower_pat) {
        out_score = 100;
        return true;
    }
    
    size_t pattern_len = lower_pat.size();
    size_t str_len = lower_str.size();
    if (pattern_len > str_len) {
        out_score = 0;
        return false;
    }
    
    size_t pattern_idx = 0;
    int score = 0;
    int consecutive = 0;
    size_t last_match_idx = 0;
    
    for (size_t i = 0; i < str_len; ++i) {
        if (lower_str[i] == lower_pat[pattern_idx]) {
            pattern_idx++;
            int distance = static_cast<int>(i - last_match_idx);
            if (distance == 1) {
                consecutive++;
                score += 10 + (consecutive * 5);
            } else {
                consecutive = 0;
                score += 10 - distance;
            }
            last_match_idx = i;
            if (pattern_idx >= pattern_len) {
                out_score = score;
                return true;
            }
        }
    }
    out_score = 0;
    return false;
}

std::string search_index(const std::string& body, long long place_id) {
    auto parts = split_header_payload(body, 1);
    if (parts.size() != 2) {
        return "{\"ok\":false,\"error\":\"invalid search payload\",\"results\":[]}";
    }

    int limit = 80;
    try {
        limit = std::max(1, std::min(200, std::stoi(parts[0])));
    } catch (...) {
        limit = 80;
    }

    std::string raw_query = parts[1];
    SearchQuery sq = parse_search_query(raw_query);

    if (raw_query.empty()) {
        std::lock_guard<std::mutex> lock(g_script_index_mutex);
        size_t count = 0;
        for (const auto& item : g_script_index) {
            if (item.second.place_id == place_id) count++;
        }
        return "{\"ok\":true,\"indexed\":" + std::to_string(count) + ",\"total\":0,\"results\":[]}";
    }

    if (!g_db && !init_db()) {
        return "{\"ok\":false,\"error\":\"database not initialized\",\"results\":[]}";
    }

    struct Hit {
        IndexedScript entry;
        int score;
        size_t pos;
        std::string match_type;
        std::string matched_token;
        double confidence;
    };
    std::vector<Hit> hits;

    if (sq.mode == MODE_NORMAL) {
        std::string query = lower_copy(raw_query);
        std::string fts_query = sanitize_fts_query(query);
        std::string like_pattern = "%" + query + "%";

        std::string sql;
        bool use_fts = !fts_query.empty();
        if (use_fts) {
            sql = "SELECT key, path, name, class_name, source, analysis, updated_at FROM indexed_scripts "
                  "WHERE place_id = ? AND (key IN (SELECT key FROM indexed_scripts_fts WHERE place_id = ? AND indexed_scripts_fts MATCH ?) "
                  "OR path LIKE ? OR source LIKE ? OR name LIKE ?) "
                  "LIMIT ?;";
        } else {
            sql = "SELECT key, path, name, class_name, source, analysis, updated_at FROM indexed_scripts "
                  "WHERE place_id = ? AND (path LIKE ? OR source LIKE ? OR name LIKE ?) "
                  "LIMIT ?;";
        }

        sqlite3_stmt* stmt = nullptr;
        int rc = sqlite3_prepare_v2(g_db, sql.c_str(), -1, &stmt, nullptr);
        if (rc != SQLITE_OK) {
            return "{\"ok\":false,\"error\":\"prepare search query failed: " + std::string(sqlite3_errmsg(g_db)) + "\",\"results\":[]}";
        }

        int bind_idx = 1;
        sqlite3_bind_int64(stmt, bind_idx++, place_id);
        if (use_fts) {
            sqlite3_bind_int64(stmt, bind_idx++, place_id);
            sqlite3_bind_text(stmt, bind_idx++, fts_query.c_str(), -1, SQLITE_TRANSIENT);
        }
        sqlite3_bind_text(stmt, bind_idx++, like_pattern.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, bind_idx++, like_pattern.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, bind_idx++, like_pattern.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, bind_idx++, limit * 2);

        while (sqlite3_step(stmt) == SQLITE_ROW) {
            IndexedScript entry;
            const char* key_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
            entry.place_id = place_id;
            const char* path_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
            const char* name_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
            const char* class_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
            const char* source_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
            const char* analysis_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));

            if (key_text) entry.key = key_text;
            if (path_text) entry.path = path_text;
            if (name_text) entry.name = name_text;
            if (class_text) entry.class_name = class_text;
            if (source_text) entry.source = source_text;
            if (analysis_text) entry.analysis = analysis_text;

            entry.updated_at = static_cast<std::time_t>(sqlite3_column_int64(stmt, 6));
            entry.lower_source = lower_copy(entry.source);
            entry.lower_path = lower_copy(entry.path);
            entry.top_identifiers = top_identifiers(entry.source, 12);

            size_t path_pos = entry.lower_path.find(query);
            size_t source_pos = entry.lower_source.find(query);
            std::string lower_name = lower_copy(entry.name);
            size_t name_pos = lower_name.find(query);
            std::string matched_identifier;
            size_t identifier_pos = std::string::npos;
            for (const auto& identifier : entry.top_identifiers) {
                std::string lower_identifier = lower_copy(identifier_name(identifier));
                if (lower_identifier.find(query) != std::string::npos || query.find(lower_identifier) != std::string::npos) {
                    identifier_pos = entry.lower_source.find(lower_identifier);
                    matched_identifier = identifier;
                    break;
                }
            }

            if (path_pos == std::string::npos && source_pos == std::string::npos && name_pos == std::string::npos && identifier_pos == std::string::npos) {
                int score = 5;
                hits.push_back({std::move(entry), score, 0, "source", query, confidence_for_match("source", score)});
                continue;
            }

            int score = 10;
            if (path_pos != std::string::npos) score += 30;
            if (source_pos != std::string::npos) score += 15;
            if (name_pos == 0 && lower_name == query) score += 40;
            else if (name_pos != std::string::npos) score += 20;
            if (identifier_pos != std::string::npos) score += 25;

            std::string match_type = "source";
            size_t pos = source_pos != std::string::npos ? source_pos : 0;
            std::string matched_token = query;
            if (path_pos != std::string::npos) {
                match_type = "path";
                pos = source_pos != std::string::npos ? source_pos : 0;
            }
            if (identifier_pos != std::string::npos) {
                match_type = "identifier";
                matched_token = matched_identifier;
                if (source_pos != std::string::npos) pos = source_pos;
            }
            if (name_pos != std::string::npos) {
                match_type = "name";
                matched_token = entry.name;
                if (source_pos != std::string::npos) pos = source_pos;
            }

            hits.push_back({std::move(entry), score, pos, match_type, matched_token, confidence_for_match(match_type, score)});
        }
        sqlite3_finalize(stmt);
    } else {
        std::regex reg;
        bool regex_valid = false;
        if (sq.mode == MODE_REGEX) {
            try {
                reg = std::regex(sq.pattern, std::regex_constants::ECMAScript | std::regex_constants::icase);
                regex_valid = true;
            } catch (...) {
                return "{\"ok\":false,\"error\":\"invalid regular expression pattern\",\"results\":[]}";
            }
        }

        std::string sql = "SELECT key, path, name, class_name, source, analysis, updated_at FROM indexed_scripts WHERE place_id = ?;";
        sqlite3_stmt* stmt = nullptr;
        int rc = sqlite3_prepare_v2(g_db, sql.c_str(), -1, &stmt, nullptr);
        if (rc != SQLITE_OK) {
            return "{\"ok\":false,\"error\":\"prepare search query failed: " + std::string(sqlite3_errmsg(g_db)) + "\",\"results\":[]}";
        }
        sqlite3_bind_int64(stmt, 1, place_id);

        while (sqlite3_step(stmt) == SQLITE_ROW) {
            IndexedScript entry;
            const char* key_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
            entry.place_id = place_id;
            const char* path_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
            const char* name_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
            const char* class_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
            const char* source_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
            const char* analysis_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));

            if (key_text) entry.key = key_text;
            if (path_text) entry.path = path_text;
            if (name_text) entry.name = name_text;
            if (class_text) entry.class_name = class_text;
            if (source_text) entry.source = source_text;
            if (analysis_text) entry.analysis = analysis_text;

            entry.updated_at = static_cast<std::time_t>(sqlite3_column_int64(stmt, 6));
            entry.lower_source = lower_copy(entry.source);
            entry.lower_path = lower_copy(entry.path);

            bool matched = false;
            int score = 0;
            size_t pos = 0;
            std::string match_type = "source";
            std::string matched_token = "";

            if (sq.mode == MODE_REGEX && regex_valid) {
                std::smatch match_path;
                std::smatch match_name;
                std::smatch match_source;
                bool path_ok = std::regex_search(entry.path, match_path, reg);
                bool name_ok = std::regex_search(entry.name, match_name, reg);
                bool source_ok = std::regex_search(entry.source, match_source, reg);

                if (path_ok || name_ok || source_ok) {
                    matched = true;
                    if (name_ok) {
                        score += 50;
                        match_type = "name";
                        matched_token = match_name.str();
                    }
                    if (path_ok) {
                        score += 40;
                        if (match_type == "source") {
                            match_type = "path";
                            matched_token = match_path.str();
                        }
                    }
                    if (source_ok) {
                        score += 25;
                        pos = match_source.position();
                        if (match_type == "source") {
                            matched_token = match_source.str();
                        }
                    }
                }
            } else if (sq.mode == MODE_FUZZY) {
                int path_score = 0;
                int name_score = 0;
                int source_score = 0;
                bool path_ok = fuzzy_match(entry.path, sq.pattern, path_score);
                bool name_ok = fuzzy_match(entry.name, sq.pattern, name_score);
                bool source_ok = false;
                if (entry.source.size() < 100000) {
                    source_ok = fuzzy_match(entry.source, sq.pattern, source_score);
                }

                if (path_ok || name_ok || source_ok) {
                    matched = true;
                    score = std::max({path_score, name_score, source_score});
                    if (name_score >= path_score && name_score >= source_score) {
                        match_type = "name";
                        matched_token = entry.name;
                    } else if (path_score >= source_score) {
                        match_type = "path";
                        matched_token = entry.path;
                    } else {
                        match_type = "source";
                        matched_token = sq.pattern;
                        if (!sq.pattern.empty()) {
                            size_t first_char_pos = entry.lower_source.find(tolower(sq.pattern[0]));
                            pos = first_char_pos != std::string::npos ? first_char_pos : 0;
                        }
                    }
                }
            }

            if (matched) {
                hits.push_back({std::move(entry), score, pos, match_type, matched_token, confidence_for_match(match_type, score)});
            }
        }
        sqlite3_finalize(stmt);
    }

    std::sort(hits.begin(), hits.end(), [](const Hit& a, const Hit& b) {
        if (a.score == b.score) return a.entry.path < b.entry.path;
        return a.score > b.score;
    });

    size_t total_indexed = 0;
    {
        std::lock_guard<std::mutex> lock(g_script_index_mutex);
        for (const auto& item : g_script_index) {
            if (item.second.place_id == place_id) total_indexed++;
        }
    }

    std::stringstream json;
    json << "{\"ok\":true,\"indexed\":" << total_indexed
         << ",\"total\":" << hits.size() << ",\"results\":[";
    for (int i = 0; i < static_cast<int>(hits.size()) && i < limit; ++i) {
        const IndexedScript& entry = hits[i].entry;
        if (i > 0) json << ",";
        json << "{\"key\":\"" << escape_json(entry.key) << "\",";
        json << "\"path\":\"" << escape_json(entry.path) << "\",";
        json << "\"name\":\"" << escape_json(entry.name) << "\",";
        json << "\"className\":\"" << escape_json(entry.class_name) << "\",";
        json << "\"score\":" << hits[i].score << ",";
        json << "\"matchType\":\"" << escape_json(hits[i].match_type) << "\",";
        json << "\"matchedToken\":\"" << escape_json(hits[i].matched_token) << "\",";
        json << "\"confidence\":" << hits[i].confidence << ",";
        json << "\"updatedAt\":" << static_cast<long long>(entry.updated_at) << ",";
        json << "\"snippet\":\"" << escape_json(make_snippet(entry.source, hits[i].pos)) << "\",";
        json << "\"analysis\":" << entry.analysis << "}";
    }
    json << "]}";
    return json.str();
}

std::string index_entry(const std::string& key, long long place_id) {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    std::string map_key = std::to_string(place_id) + "|" + trim_copy(key);
    auto found = g_script_index.find(map_key);
    if (found == g_script_index.end()) {
        return "{\"ok\":false,\"error\":\"script not found\"}";
    }

    const IndexedScript& entry = found->second;
    std::stringstream json;
    json << "{\"ok\":true,"
         << "\"key\":\"" << escape_json(entry.key) << "\","
         << "\"path\":\"" << escape_json(entry.path) << "\","
         << "\"name\":\"" << escape_json(entry.name) << "\","
         << "\"className\":\"" << escape_json(entry.class_name) << "\","
         << "\"updatedAt\":" << static_cast<long long>(entry.updated_at) << ","
         << "\"source\":\"" << escape_json(entry.source) << "\","
         << "\"analysis\":" << entry.analysis
         << "}";
    return json.str();
}


void write_field(std::ostream& out, const std::string& value) {
    out << value.size() << "\n";
    out.write(value.data(), static_cast<std::streamsize>(value.size()));
    out << "\n";
}

bool read_field(std::istream& in, std::string& value) {
    std::string length_line;
    if (!std::getline(in, length_line)) return false;
    if (!length_line.empty() && length_line.back() == '\r') length_line.pop_back();

    size_t length = 0;
    try {
        length = static_cast<size_t>(std::stoull(length_line));
    } catch (...) {
        return false;
    }

    value.assign(length, '\0');
    if (length > 0) {
        in.read(&value[0], static_cast<std::streamsize>(length));
        if (static_cast<size_t>(in.gcount()) != length) return false;
    }

    char newline = '\0';
    in.get(newline);
    return newline == '\n';
}

sqlite3* g_db = nullptr;

bool init_db() {
    if (g_db) return true;

    std::string db_path = get_db_path();
    create_directories_for_file(to_wstring(db_path));

    int rc = sqlite3_open(db_path.c_str(), &g_db);
    if (rc != SQLITE_OK) {
        std::cerr << "Cannot open database: " << sqlite3_errmsg(g_db) << std::endl;
        return false;
    }

    bool has_place_id = false;
    sqlite3_stmt* check_stmt = nullptr;
    if (sqlite3_prepare_v2(g_db, "PRAGMA table_info(indexed_scripts);", -1, &check_stmt, nullptr) == SQLITE_OK) {
        while (sqlite3_step(check_stmt) == SQLITE_ROW) {
            const char* name = reinterpret_cast<const char*>(sqlite3_column_text(check_stmt, 1));
            if (name && std::string(name) == "place_id") {
                has_place_id = true;
                break;
            }
        }
        sqlite3_finalize(check_stmt);
    } else {
        has_place_id = true; 
    }

    if (!has_place_id) {
        sqlite3_exec(g_db, "DROP TABLE IF EXISTS indexed_scripts; DROP TABLE IF EXISTS indexed_scripts_fts;", nullptr, nullptr, nullptr);
    }
    
    const char* sql = "CREATE TABLE IF NOT EXISTS indexed_scripts ("
                      "key TEXT, "
                      "place_id INTEGER, "
                      "path TEXT, "
                      "name TEXT, "
                      "class_name TEXT, "
                      "source TEXT, "
                      "analysis TEXT, "
                      "updated_at INTEGER, "
                      "PRIMARY KEY (key, place_id)"
                      ");";
    char* err_msg = nullptr;
    rc = sqlite3_exec(g_db, sql, nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        std::cerr << "SQL error creating table: " << (err_msg ? err_msg : "unknown") << std::endl;
        sqlite3_free(err_msg);
        return false;
    }
    
    const char* fts_sql = "CREATE VIRTUAL TABLE IF NOT EXISTS indexed_scripts_fts USING fts4("
                          "key, place_id, path, name, source"
                          ");";
    rc = sqlite3_exec(g_db, fts_sql, nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        std::cerr << "FTS4 warning: " << (err_msg ? err_msg : "unknown") << std::endl;
        sqlite3_free(err_msg);
    }
    return true;
}

void close_db() {
    if (g_db) {
        sqlite3_close(g_db);
        g_db = nullptr;
    }
}

bool save_index_locked() {
    if (!g_db && !init_db()) return false;
    if (g_script_index.empty()) {
        clear_db();
    }
    return true;
}

std::string save_index_response() {
    std::lock_guard<std::mutex> lock(g_script_index_mutex);
    std::stringstream json;
    json << "{\"ok\":true,\"scripts\":" << g_script_index.size()
         << ",\"file\":\"" << get_db_path() << "\"}";
    return json.str();
}

std::string load_index_response() {
    if (!g_db && !init_db()) {
        return "{\"ok\":false,\"error\":\"could not initialize database\",\"scripts\":0}";
    }
    
    const char* query = "SELECT key, place_id, path, name, class_name, source, analysis, updated_at FROM indexed_scripts;";
    sqlite3_stmt* stmt = nullptr;
    int rc = sqlite3_prepare_v2(g_db, query, -1, &stmt, nullptr);
    if (rc != SQLITE_OK) {
        return "{\"ok\":false,\"error\":\"prepare statement failed: " + std::string(sqlite3_errmsg(g_db)) + "\",\"scripts\":0}";
    }
    
    std::unordered_map<std::string, IndexedScript> loaded;
    size_t count = 0;
    
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        IndexedScript entry;
        const char* key_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        entry.place_id = sqlite3_column_int64(stmt, 1);
        const char* path_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
        const char* name_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
        const char* class_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
        const char* source_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
        const char* analysis_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
        
        if (key_text) entry.key = key_text;
        if (path_text) entry.path = path_text;
        if (name_text) entry.name = name_text;
        if (class_text) entry.class_name = class_text;
        if (source_text) entry.source = source_text;
        if (analysis_text) entry.analysis = analysis_text;
        
        entry.updated_at = static_cast<std::time_t>(sqlite3_column_int64(stmt, 7));
        entry.lower_source = lower_copy(entry.source);
        entry.lower_path = lower_copy(entry.path);
        entry.top_identifiers = top_identifiers(entry.source, 12);
        
        if (!entry.key.empty()) {
            std::string map_key = std::to_string(entry.place_id) + "|" + entry.key;
            loaded[map_key] = std::move(entry);
            count++;
        }
    }
    sqlite3_finalize(stmt);
    
    {
        std::lock_guard<std::mutex> lock(g_script_index_mutex);
        g_script_index = std::move(loaded);
    }
    
    std::stringstream json;
    json << "{\"ok\":true,\"scripts\":" << count << ",\"file\":\"" << get_db_path() << "\"}";
    return json.str();
}
