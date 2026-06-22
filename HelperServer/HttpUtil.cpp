#include "HttpUtil.h"

void send_response(
    SOCKET client_socket,
    int status_code,
    const std::string& status_text,
    const std::string& body,
    const std::string& content_type
) {
    std::stringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n"
             << "Content-Type: " << content_type << "\r\n"
             << "Content-Length: " << body.length() << "\r\n"
             << "Access-Control-Allow-Origin: *\r\n"
             << "Access-Control-Allow-Headers: *\r\n"
             << "Connection: close\r\n\r\n"
             << body;

    std::string response_str = response.str();
    send(client_socket, response_str.c_str(), static_cast<int>(response_str.length()), 0);
}

void close_client(SOCKET client_socket) {
    shutdown(client_socket, SD_SEND);
    closesocket(client_socket);
}
