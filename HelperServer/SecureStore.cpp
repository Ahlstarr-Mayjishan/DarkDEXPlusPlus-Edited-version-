#include "SecureStore.h"

#include <wincrypt.h>

#pragma comment(lib, "crypt32.lib")

namespace {

constexpr const char* kPrefix = "DPAPI1:";

std::string base64_encode(const std::string& input) {
    DWORD out_len = 0;
    if (!CryptBinaryToStringA(
            reinterpret_cast<const BYTE*>(input.data()),
            static_cast<DWORD>(input.size()),
            CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
            nullptr,
            &out_len)) {
        return input;
    }

    std::string output(out_len, '\0');
    if (!CryptBinaryToStringA(
            reinterpret_cast<const BYTE*>(input.data()),
            static_cast<DWORD>(input.size()),
            CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
            output.data(),
            &out_len)) {
        return input;
    }

    while (!output.empty() && output.back() == '\0') {
        output.pop_back();
    }
    return output;
}

std::string base64_decode(const std::string& input) {
    DWORD out_len = 0;
    if (!CryptStringToBinaryA(
            input.c_str(),
            static_cast<DWORD>(input.size()),
            CRYPT_STRING_BASE64,
            nullptr,
            &out_len,
            nullptr,
            nullptr)) {
        return "";
    }

    std::string output(out_len, '\0');
    if (!CryptStringToBinaryA(
            input.c_str(),
            static_cast<DWORD>(input.size()),
            CRYPT_STRING_BASE64,
            reinterpret_cast<BYTE*>(output.data()),
            &out_len,
            nullptr,
            nullptr)) {
        return "";
    }
    output.resize(out_len);
    return output;
}

std::string dpapi_protect(const std::string& plaintext) {
    if (plaintext.empty()) {
        return "";
    }

    DATA_BLOB input{};
    input.pbData = reinterpret_cast<BYTE*>(const_cast<char*>(plaintext.data()));
    input.cbData = static_cast<DWORD>(plaintext.size());

    DATA_BLOB output{};
    if (!CryptProtectData(&input, L"DEX++ Helper", nullptr, nullptr, nullptr, 0, &output)) {
        return plaintext;
    }

    std::string cipher(reinterpret_cast<char*>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    return kPrefix + base64_encode(cipher);
}

std::string dpapi_unprotect(const std::string& stored) {
    if (stored.rfind(kPrefix, 0) != 0) {
        return stored;
    }

    std::string cipher = base64_decode(stored.substr(std::char_traits<char>::length(kPrefix)));
    if (cipher.empty()) {
        return stored;
    }

    DATA_BLOB input{};
    input.pbData = reinterpret_cast<BYTE*>(cipher.data());
    input.cbData = static_cast<DWORD>(cipher.size());

    DATA_BLOB output{};
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, 0, &output)) {
        return stored;
    }

    std::string plaintext(reinterpret_cast<char*>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    return plaintext;
}

} // namespace

std::string secure_protect(const std::string& plaintext) {
    return dpapi_protect(plaintext);
}

std::string secure_unprotect(const std::string& stored) {
    return dpapi_unprotect(stored);
}
