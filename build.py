import os
import subprocess
import sys

LIB_REPLACEMENTS = [
    ("\t-- Signal + Set live in Modules/Core/Lib/SignalSet.luau (merged at build time)", "SignalSet.luau"),
    ("\t-- ScrollBar lives in Modules/Core/Lib/ScrollBar.luau (merged at build time)", "ScrollBar.luau"),
    ("\t-- Window lives in Modules/Core/Lib/Window.luau (merged at build time)", "Window.luau"),
    ("\t-- ContextMenu lives in Modules/Core/Lib/ContextMenu.luau (merged at build time)", "ContextMenu.luau"),
    ("\t-- Checkbox lives in Modules/Core/LibParts/Checkbox.luau (merged at build time)", "Checkbox.luau"),
    ("\t-- ColorPicker lives in Modules/Core/LibParts/ColorPicker.luau (merged at build time)", "ColorPicker.luau"),
    ("\t-- SequenceEditors lives in Modules/Core/LibParts/SequenceEditors.luau (merged at build time)", "SequenceEditors.luau"),
    ("\t-- BasicUI lives in Modules/Core/LibParts/BasicUI.luau (merged at build time)", "BasicUI.luau"),
    ("\t-- DropDown lives in Modules/Core/LibParts/DropDown.luau (merged at build time)", "DropDown.luau"),
    ("\t-- ClickSystem lives in Modules/Core/LibParts/ClickSystem.luau (merged at build time)", "ClickSystem.luau"),
]

def read_module_source(name, filepath):
    with open(filepath, "r", encoding="utf-8") as mf:
        m_code = mf.read().strip()

    if name == "Lib":
        for marker, filename in LIB_REPLACEMENTS:
            part_path = os.path.join("Modules", "Core", "LibParts", filename)
            if os.path.exists(part_path):
                with open(part_path, "r", encoding="utf-8") as pf:
                    part_code = pf.read().strip()
                m_code = m_code.replace(marker + "\n", part_code + "\n\n")
                m_code = m_code.replace(marker, part_code + "\n\n")

    return m_code

def lua_long_string(value):
    level = 0
    while "]" + ("=" * level) + "]" in value:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{value}\n]{eq}]"

def build():
    # Run unit tests first
    test_script = os.path.join("scripts", "run_tests.py")
    if os.path.exists(test_script):
        print("Running unit tests...")
        result = subprocess.run([sys.executable, test_script], check=False)
        if result.returncode != 0:
            print("[-] Unit tests failed! Aborting compilation.")
            sys.exit(1)
        print("[+] All unit tests passed!")

    print("Building DEX++_compiled.luau...")
    
    # Read the hollow shell
    shell_path = "DEX++.luau"
    if not os.path.exists(shell_path):
        print(f"Error: Hollow shell '{shell_path}' not found!")
        return

    with open(shell_path, "r", encoding="utf-8") as f:
        template = f.read()

    # Load module files and format them for insertion.
    # Runtime module names stay flat for Apps.<Name>, while source files are
    # grouped by ownership so the repo is easier to navigate.
    module_groups = {
        "Core": [
            "Theme", "State", "Logger", "IconData", "Lib", "Console", "SettingsWindow", "ControlCenter",
            "TaskRouter", "ThreadManager", "Config", "HookManager", "DecompilerService", "HelperClient",
            "Bypasses", "ReflectionMetadata", "Intro", "WebSocketClient", "MainMenu", "LucideDockIcons",
        ],
        "Explorer": [
            "Explorer", "EditMenu", "NavigationMenu", "ObjectMenu", "ScriptMenu", "InteractionMenu", "PlayerMenu", "NilInstanceMenu", "Properties", "SaveInstance", "ObjectLinks", "InstanceSerializer",
            "Clipboard", "Duplicate", "Deletion", "PropertyCopier", "PropertyRestorer", "Rename", "History",
        ],
        "Roblox Assets Viewer": [
            "ModelViewer", "ImageViewer", "SoundViewer", "AnimationViewer",
        ],
        "Search": [
            "SmartDecompiler", "Notepad", "ClientIndex", "CodeSearch",
            "SmartSearch", "DependencyGraph", "ScriptRelations",
            "SecurityAuditor", "SnippetLibrary",
        ],
        "Runtime": [
            "RuntimeInspector", "RemoteUsageMap", "ActivityMap",
            "PropertyTracker", "RemoteFuzzer", "ClientIntelligence",
            "InspectorHub",
        ],
        "Tools": [
            "IDESync",
        ],
    }
    module_list = [name for names in module_groups.values() for name in names]
    module_paths = {}
    for group, names in module_groups.items():
        for name in names:
            if name.endswith("Menu") and name != "MainMenu":
                module_paths[name] = os.path.join("Modules", group, "ContextMenu", f"{name}.luau")
            elif group == "Roblox Assets Viewer":
                module_paths[name] = os.path.join("Modules", "Explorer", "ContextMenu", "Roblox Assets Viewer", f"{name}.luau")
            else:
                module_paths[name] = os.path.join("Modules", group, f"{name}.luau")
    
    embedded_str = ""
    for name in module_list:
        filepath = module_paths.get(name, os.path.join("Modules", f"{name}.luau"))
        if not os.path.exists(filepath):
            filepath = filepath[:-5] + ".lua" if filepath.endswith(".luau") else os.path.join("Modules", f"{name}.lua")
            
        with open(filepath, "r", encoding="utf-8") as mf:
            m_code = read_module_source(name, filepath)
        
        # Indent the module code for clean formatting inside EmbeddedModules
        indented_code = "\n".join("    " + line for line in m_code.splitlines())
        embedded_str += f'["{name}"] = function()\n{indented_code}\nend,\n'

    plugin_entries = []
    plugin_dir = "Plugins"
    if os.path.isdir(plugin_dir):
        for filename in sorted(os.listdir(plugin_dir)):
            if not (filename.endswith(".luau") or filename.endswith(".lua")):
                continue
            plugin_path = os.path.join(plugin_dir, filename)
            with open(plugin_path, "r", encoding="utf-8") as pf:
                plugin_code = pf.read().strip()
            out_name = os.path.splitext(filename)[0] + ".lua"
            plugin_entries.append(f'["{out_name}"] = {lua_long_string(plugin_code)},')

    # Replace placeholders
    compiled = template.replace("-- [[EMBEDDED_MODULES_PLACEHOLDER]]", embedded_str.strip())
    compiled = compiled.replace("-- [[PLUGIN_SOURCES_PLACEHOLDER]]", "\n\t".join(plugin_entries))

    with open("DEX++_compiled.luau", "w", encoding="utf-8") as out:
        out.write(compiled)
    print("Built DEX++_compiled.luau successfully!")

    verify_script = os.path.join("scripts", "verify_build.py")
    if os.path.exists(verify_script):
        print("Running build verification...")
        result = subprocess.run([sys.executable, verify_script], check=False)
        if result.returncode != 0:
            raise SystemExit(result.returncode)

if __name__ == "__main__":
    build()
