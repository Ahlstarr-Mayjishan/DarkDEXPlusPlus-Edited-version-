#pragma once
#include "Common.h"

std::string secure_protect(const std::string& plaintext);
std::string secure_unprotect(const std::string& stored);
