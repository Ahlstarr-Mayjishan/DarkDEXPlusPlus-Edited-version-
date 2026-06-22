#pragma once
#include "Common.h"

namespace sha1 {
    std::string hash(const std::string& input);
}

namespace base64 {
    std::string encode(const std::string& input);
}

bool send_ws_text_frame(SOCKET client_socket, const std::string& payload);
bool recv_all(SOCKET s, char* buf, int len);
bool read_ws_text_frame(SOCKET client_socket, std::string& out_payload);
bool perform_ws_handshake(SOCKET ClientSocket, const std::string& request_headers);
