#pragma once
#include "Common.h"

enum class RouteDispatchResult {
    Handled,
    NotFound,
    CloseConnection,
};

RouteDispatchResult dispatch_http_routes(
    SOCKET client_socket,
    const std::string& method,
    const std::string& path,
    const std::string& body,
    const std::string& request_data
);
