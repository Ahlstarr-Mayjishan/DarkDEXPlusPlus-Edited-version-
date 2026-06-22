#!/usr/bin/env python3
"""One-time helper to generate Routes.cpp from main.cpp dispatch block."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main_cpp = (ROOT / "HelperServer" / "main.cpp").read_text(encoding="utf-8")

start_marker = '        } else if ((path == "/" || path == "/app") && method == "GET") {'
end_marker = "        } else {\n            send_response(ClientSocket, 404, \"Not Found\", \"404 Route Not Found\");\n        }"

start = main_cpp.find(start_marker)
end = main_cpp.find(end_marker)
if start == -1 or end == -1:
    raise SystemExit("Could not locate dispatch block in main.cpp")

block = main_cpp[start:end]
block = block.replace("ClientSocket", "client_socket")
block = block.replace("        } else if ((path == \"/\" || path == \"/app\")", "        if ((path == \"/\" || path == \"/app\")", 1)

routes_cpp = f'''#include "Routes.h"

#include "Auth.h"
#include "Dashboard.h"
#include "Decompiler.h"
#include "HttpUtil.h"
#include "Index.h"
#include "Toolchain.h"
#include "Win32App.h"

RouteDispatchResult dispatch_http_routes(
    SOCKET client_socket,
    const std::string& method,
    const std::string& path,
    const std::string& body,
    const std::string& request_data
) {{
{block}
    return RouteDispatchResult::NotFound;
}}
'''

routes_cpp = routes_cpp.replace("            return;", "            return RouteDispatchResult::CloseConnection;")
routes_cpp = routes_cpp.replace("\n        } else if", "\n            return RouteDispatchResult::Handled;\n        } else if")
routes_cpp = routes_cpp.rstrip() + "\n            return RouteDispatchResult::Handled;\n"

(ROOT / "HelperServer" / "Routes.cpp").write_text(routes_cpp, encoding="utf-8")
print("Wrote HelperServer/Routes.cpp")
