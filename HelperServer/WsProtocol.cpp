#include "WsProtocol.h"
#include "HttpUtil.h"

// Lightweight SHA-1 implementation
namespace sha1 {
    inline unsigned int rol(unsigned int value, unsigned int bits) {
        return (value << bits) | (value >> (32 - bits));
    }
    inline void block(unsigned int* state, const unsigned char* block) {
        unsigned int w[80];
        for (int i = 0; i < 16; i++) {
            w[i] = (block[i * 4] << 24) | (block[i * 4 + 1] << 16) | (block[i * 4 + 2] << 8) | (block[i * 4 + 3]);
        }
        for (int i = 16; i < 80; i++) {
            w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
        }
        unsigned int a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];
        for (int i = 0; i < 80; i++) {
            unsigned int f, k;
            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5A827999;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ED9EBA1;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8F1BBCDC;
            } else {
                f = b ^ c ^ d;
                k = 0xCA62C1D6;
            }
            unsigned int temp = rol(a, 5) + f + e + k + w[i];
            e = d;
            d = c;
            c = rol(b, 30);
            b = a;
            a = temp;
        }
        state[0] += a; state[1] += b; state[2] += c; state[3] += d; state[4] += e;
    }
    std::string hash(const std::string& input) {
        unsigned int state[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};
        unsigned long long bit_len = input.size() * 8;
        std::vector<unsigned char> data(input.begin(), input.end());
        data.push_back(0x80);
        while ((data.size() + 8) % 64 != 0) {
            data.push_back(0x00);
        }
        for (int i = 7; i >= 0; i--) {
            data.push_back(static_cast<unsigned char>((bit_len >> (i * 8)) & 0xFF));
        }
        for (size_t i = 0; i < data.size(); i += 64) {
            block(state, &data[i]);
        }
        std::string result;
        result.resize(20);
        for (int i = 0; i < 5; i++) {
            result[i * 4] = static_cast<char>((state[i] >> 24) & 0xFF);
            result[i * 4 + 1] = static_cast<char>((state[i] >> 16) & 0xFF);
            result[i * 4 + 2] = static_cast<char>((state[i] >> 8) & 0xFF);
            result[i * 4 + 3] = static_cast<char>(state[i] & 0xFF);
        }
        return result;
    }
}

// Lightweight Base64 implementation
namespace base64 {
    std::string encode(const std::string& input) {
        static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        std::string result;
        result.reserve((input.size() + 2) / 3 * 4);
        int val = 0, valb = -6;
        for (unsigned char c : input) {
            val = (val << 8) + c;
            valb += 8;
            while (valb >= 0) {
                result.push_back(alphabet[(val >> valb) & 0x3F]);
                valb -= 6;
            }
        }
        if (valb > -6) {
            result.push_back(alphabet[((val << 8) >> (valb + 8)) & 0x3F]);
        }
        while (result.size() % 4 != 0) {
            result.push_back('=');
        }
        return result;
    }
}

// Send unmasked WebSocket text frame
bool send_ws_text_frame(SOCKET client_socket, const std::string& payload) {
    std::vector<char> frame;
    frame.push_back(static_cast<char>(0x81)); // FIN + Text frame opcode
    
    size_t len = payload.size();
    if (len <= 125) {
        frame.push_back(static_cast<char>(len));
    } else if (len <= 65535) {
        frame.push_back(static_cast<char>(126));
        frame.push_back(static_cast<char>((len >> 8) & 0xFF));
        frame.push_back(static_cast<char>(len & 0xFF));
    } else {
        frame.push_back(static_cast<char>(127));
        for (int i = 7; i >= 0; i--) {
            frame.push_back(static_cast<char>((len >> (i * 8)) & 0xFF));
        }
    }
    
    frame.insert(frame.end(), payload.begin(), payload.end());
    
    size_t total_sent = 0;
    while (total_sent < frame.size()) {
        int sent = send(client_socket, frame.data() + total_sent, static_cast<int>(frame.size() - total_sent), 0);
        if (sent == SOCKET_ERROR || sent == 0) {
            return false;
        }
        total_sent += sent;
    }
    return true;
}

bool recv_all(SOCKET s, char* buf, int len) {
    int total = 0;
    while (total < len) {
        int r = recv(s, buf + total, len - total, 0);
        if (r <= 0) return false;
        total += r;
    }
    return true;
}

bool read_ws_text_frame(SOCKET client_socket, std::string& out_payload) {
    while (true) {
        char header[2];
        if (!recv_all(client_socket, header, 2)) {
            int err = WSAGetLastError();
            if (err != 0 && err != WSAEDISCON) {
                std::cout << "WS Read: recv_all header failed, error: " << err << std::endl;
            }
            return false;
        }
        
        unsigned char first_byte = header[0];
        unsigned char second_byte = header[1];
        
        bool fin = (first_byte & 0x80) != 0;
        unsigned char opcode = first_byte & 0x0F;
        
        if (opcode == 0x08) { // Close
            std::cout << "WS Read: Received Close frame." << std::endl;
            return false;
        }
        
        bool masked = (second_byte & 0x80) != 0;
        uint64_t payload_len = second_byte & 0x7F;
        
        if (payload_len == 126) {
            char len_bytes[2];
            if (!recv_all(client_socket, len_bytes, 2)) {
                std::cout << "WS Read: recv_all len_bytes(126) failed" << std::endl;
                return false;
            }
            payload_len = (static_cast<unsigned char>(len_bytes[0]) << 8) | static_cast<unsigned char>(len_bytes[1]);
        } else if (payload_len == 127) {
            char len_bytes[8];
            if (!recv_all(client_socket, len_bytes, 8)) {
                std::cout << "WS Read: recv_all len_bytes(127) failed" << std::endl;
                return false;
            }
            payload_len = 0;
            for (int i = 0; i < 8; i++) {
                payload_len = (payload_len << 8) | static_cast<unsigned char>(len_bytes[i]);
            }
        }
        
        char mask_key[4] = {0};
        if (masked) {
            if (!recv_all(client_socket, mask_key, 4)) {
                std::cout << "WS Read: recv_all mask_key failed" << std::endl;
                return false;
            }
        }
        
        std::vector<char> buffer;
        if (payload_len > 0) {
            if (payload_len > 50 * 1024 * 1024) {
                std::cout << "WS Read: Payload too large: " << payload_len << std::endl;
                return false;
            }
            if (payload_len > static_cast<uint64_t>(INT_MAX)) {
                std::cout << "WS Read: Payload length exceeds recv limit" << std::endl;
                return false;
            }
            const int recv_len = static_cast<int>(payload_len);
            buffer.resize(static_cast<size_t>(payload_len));
            if (!recv_all(client_socket, buffer.data(), recv_len)) {
                std::cout << "WS Read: recv_all payload failed" << std::endl;
                return false;
            }
            if (masked) {
                for (size_t i = 0; i < payload_len; i++) {
                    buffer[i] ^= mask_key[i % 4];
                }
            }
        }
        
        if (opcode == 0x09) { // Ping
            std::vector<char> pong_frame;
            pong_frame.push_back(static_cast<char>(0x8A));
            size_t len = buffer.size();
            if (len <= 125) {
                pong_frame.push_back(static_cast<char>(len));
            } else if (len <= 65535) {
                pong_frame.push_back(static_cast<char>(126));
                pong_frame.push_back(static_cast<char>((len >> 8) & 0xFF));
                pong_frame.push_back(static_cast<char>(len & 0xFF));
            } else {
                pong_frame.push_back(static_cast<char>(127));
                for (int i = 7; i >= 0; i--) {
                    pong_frame.push_back(static_cast<char>((len >> (i * 8)) & 0xFF));
                }
            }
            pong_frame.insert(pong_frame.end(), buffer.begin(), buffer.end());
            send(client_socket, pong_frame.data(), static_cast<int>(pong_frame.size()), 0);
            continue;
        }
        
        if (opcode == 0x0A) { // Pong
            continue;
        }
        
        if (opcode == 0x01 || opcode == 0x02 || opcode == 0x00) {
            out_payload.assign(buffer.begin(), buffer.end());
            return true;
        }
        
        std::cout << "WS Read: Unknown opcode: " << static_cast<int>(opcode) << std::endl;
        return false;
    }
}

bool perform_ws_handshake(SOCKET ClientSocket, const std::string& request_headers) {
    size_t key_pos = request_headers.find("Sec-WebSocket-Key:");
    if (key_pos == std::string::npos) {
        send_response(ClientSocket, 400, "Bad Request", "Missing Sec-WebSocket-Key");
        close_client(ClientSocket);
        return false;
    }
    size_t value_start = key_pos + 18;
    while (value_start < request_headers.size() && std::isspace(static_cast<unsigned char>(request_headers[value_start]))) {
        value_start++;
    }
    size_t value_end = request_headers.find("\r\n", value_start);
    if (value_end == std::string::npos) value_end = request_headers.size();
    std::string ws_key = request_headers.substr(value_start, value_end - value_start);
    while (!ws_key.empty() && std::isspace(static_cast<unsigned char>(ws_key.back()))) {
        ws_key.pop_back();
    }
    
    std::string concat = ws_key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    std::string sha1_hash = sha1::hash(concat);
    std::string accept_key = base64::encode(sha1_hash);
    
    std::stringstream response;
    response << "HTTP/1.1 101 Switching Protocols\r\n"
             << "Upgrade: websocket\r\n"
             << "Connection: Upgrade\r\n"
             << "Sec-WebSocket-Accept: " << accept_key << "\r\n\r\n";
    std::string hand_str = response.str();
    send(ClientSocket, hand_str.data(), static_cast<int>(hand_str.size()), 0);
    return true;
}
