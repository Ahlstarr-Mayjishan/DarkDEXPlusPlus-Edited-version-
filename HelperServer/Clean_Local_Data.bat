@echo off
setlocal
title DEX++ Clean Local Data
echo This removes the helper index and logs, then stops ports 8080 and 56535.
echo It does not delete the DEX decompile cache inside the executor workspace.
set /p confirm=Continue? [y/N]: 
if /I not "%confirm%"=="y" exit /b 0

taskkill /IM DEX_Helper.exe /F >nul 2>nul
taskkill /IM Decompiler.exe /F >nul 2>nul
del /Q "%~dp0dex_helper_index.dat" >nul 2>nul
del /Q "%~dp0dex_server_logs.txt" >nul 2>nul
del /Q "%~dp0dex_server_logs.txt.old" >nul 2>nul
del /Q "%~dp0..\index_data\dex_helper_index.dat" >nul 2>nul
del /Q "%~dp0..\index_data\dex_helper.db" >nul 2>nul
del /Q "%~dp0..\index_data\dex_server_logs.txt" >nul 2>nul
del /Q "%~dp0..\index_data\dex_server_logs.txt.old" >nul 2>nul
echo Helper local data was cleaned.
timeout /t 2 >nul
