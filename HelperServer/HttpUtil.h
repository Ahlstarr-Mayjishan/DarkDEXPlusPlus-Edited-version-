#pragma once
#include "Common.h"

void send_response(
    SOCKET client_socket,
    int status_code,
    const std::string& status_text,
    const std::string& body,
    const std::string& content_type = "text/plain"
);
void close_client(SOCKET client_socket);
