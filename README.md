# DarkDEX++ Local Helper

DarkDEX++ can run independently using the `DEX++_compiled.luau` file, or fetch the script via the C++ Local Helper Server at `http://localhost:8080/script`.

## What does the Helper Server do?

`HelperServer/DEX_Helper.exe` currently supports:

- `GET /status`: Checks if the server is running.
- `GET /script`: Returns the content of `DEX++_compiled.luau` to be loaded locally via `loadstring`.
- `POST /deobfuscate`: Post-processes decompiled source code (e.g., renaming variables).
- `POST /analyze-source`: Quickly analyzes raw/cached source code and returns a JSON object containing the line count, function count, remote calls, risk signals, and prominent identifiers.
- `POST /index-source`: Stores a cached source file in the helper's in-memory analysis index.
- `POST /search-source`: Searches the helper's in-memory source index and returns ranked JSON results.
- `GET /index-status`: Returns the current in-memory index size.
- `POST /index-clear`: Clears the helper's in-memory source index.
- `POST /log`: Records logs from the Property Tracker into `dex_server_logs.txt`.

Important: This C++ helper is **not a bytecode decompiler**. It does not possess an engine to decompile Roblox bytecode into Luau source code, so it does not directly speed up the `decompile(script)` step. The decompile speed still depends on your executor's native decompiler, the Shiny/lua.expert fallbacks, and DarkDEX++'s built-in cache.

If `POST /decompile` is requested, the helper will return `501 Not Implemented` to avoid confusion.

## Quick Start

1. Open `HelperServer/DEX_Helper.exe`.
2. In your executor, run:

```lua
loadstring(game:HttpGet("http://localhost:8080/script"))()
```

If your executor does not allow `game:HttpGet` requests to localhost, copy the contents of `DEX++_compiled.luau` directly into the executor.

## Rebuilding

Build the Luau bundle:

```powershell
python .\build.py
```

Build the Helper C++ executable:

```powershell
cd .\HelperServer
.\compile.bat
```

If `DEX_Helper.exe` is currently running, close the helper console window before compiling, as Windows may lock the executable file.

## What should I do to decompile faster?

The most effective approach currently is using the following pipeline:

- Enable caching under `Code Search > Index Scripts`.
- Only decompile scripts that have not been cached yet.
- Use `ClientIndex` so that tools avoid scanning the instance tree repeatedly.
- Prioritize decompiling the script that is currently open/clicked first.
- Deobfuscate, run `analyze-source`, and push cached source into the helper index after the source code is retrieved.

## Local Analysis Engine

When `DEX_Helper.exe` is running, `Code Search > Index Scripts` now delegates extra work to the helper:

- decompiled/cached source is sent to `/index-source`;
- the helper keeps a fast in-memory index for the current helper session;
- `Code Search` and shared `ClientIndex.SearchCached` prefer `/search-source`;
- if the helper is offline or the helper index is empty, DarkDEX++ falls back to the old Luau cache scan.

This is intentionally session-local RAM state. It avoids background scanning and avoids keeping another database process alive. Restarting the helper clears the helper-side index; running `Index Scripts` rebuilds it.

## Copy to AI + helper analysis

In the Explorer, the `Copy to AI` option will automatically copy the object summary to your clipboard. If the object is a script that is already in the decompile cache and the local helper is running, the prompt will include the `Cached source analysis` so that the AI can understand it faster without reading the entire source code.

To make the C++ helper truly speed up decompilation, it requires a real decompiler backend that accepts bytecode and returns Luau source code. The helper does not currently feature this component.
