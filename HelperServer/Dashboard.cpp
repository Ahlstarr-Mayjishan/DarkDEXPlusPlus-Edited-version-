#include "Dashboard.h"

#include <fstream>
#include <sstream>

namespace {

std::string read_dashboard_file() {
    const char* paths[] = {
        "dashboard/index.html",
        "../HelperServer/dashboard/index.html",
        nullptr,
    };

    for (int i = 0; paths[i] != nullptr; ++i) {
        std::ifstream file(paths[i], std::ios::binary);
        if (!file.is_open()) {
            continue;
        }
        std::stringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }
    return "";
}

} // namespace

std::string helper_dashboard_html() {
    static std::string cached = read_dashboard_file();
    if (!cached.empty()) {
        return cached;
    }
    return "<!doctype html><html><body style=\"background:#0b0f14;color:#f2f5f7;font-family:Segoe UI,sans-serif;padding:24px\">"
           "<h1>Dashboard missing</h1>"
           "<p>Expected <code>dashboard/index.html</code> next to DEX_Helper.exe.</p>"
           "<p>Rebuild with <code>python scripts/extract_dashboard.py</code> if the file was deleted.</p>"
           "</body></html>";
}
