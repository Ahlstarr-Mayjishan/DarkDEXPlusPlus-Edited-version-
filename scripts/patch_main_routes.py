#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "HelperServer" / "main.cpp"
text = path.read_text(encoding="utf-8")

start = text.find('        } else if ((path == "/" || path == "/app") && method == "GET") {')
end = text.find('        } else {\n            send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");\n        }')
if start == -1 or end == -1:
    raise SystemExit("dispatch block markers not found")

replacement = """        } else {
            RouteDispatchResult route_result = dispatch_http_routes(ClientSocket, method, path, body, request_data);
            if (route_result == RouteDispatchResult::NotFound) {
                send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");
            } else if (route_result == RouteDispatchResult::CloseConnection) {
                return;
            }
        }"""

path.write_text(text[:start] + replacement + text[end + len('        } else {\n            send_response(ClientSocket, 404, "Not Found", "404 Route Not Found");\n        }'):], encoding="utf-8")
print("Updated main.cpp to use dispatch_http_routes")
