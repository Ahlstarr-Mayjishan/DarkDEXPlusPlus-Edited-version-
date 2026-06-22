@echo off
echo Compiling DEX++ Helper Server...
g++ -O3 -std=c++17 -DSQLITE_ENABLE_FTS5 main.cpp Auth.cpp SecureStore.cpp WsProtocol.cpp HttpUtil.cpp Routes.cpp Dashboard.cpp Win32App.cpp Index.cpp Toolchain.cpp Decompiler.cpp AST.cpp sqlite3.o -o DEX_Helper.exe -lws2_32 -lshell32 -lgdi32 -lwininet -lcrypt32
if %ERRORLEVEL% NEQ 0 (
    echo Compilation failed!
    exit /b %ERRORLEVEL%
)
echo Compilation successful: DEX_Helper.exe created.
