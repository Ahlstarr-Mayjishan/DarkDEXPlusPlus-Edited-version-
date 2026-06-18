import os

def replace_in_file(filepath, replacements):
    with open(filepath, "r", encoding="utf-8", newline="") as f:
        content = f.read()

    original_len = len(content)
    for old, new in replacements:
        # Normalize line endings to match file's style
        if "\r\n" in content:
            old = old.replace("\n", "\r\n")
            new = new.replace("\n", "\r\n")
        else:
            old = old.replace("\r\n", "\n")
            new = new.replace("\r\n", "\n")
            
        content = content.replace(old, new)

    if len(content) == original_len and all(old not in content for old, _ in replacements):
        print(f"No changes made to {filepath} (replacements not found or already applied)")
    else:
        with open(filepath, "w", encoding="utf-8", newline="") as f:
            f.write(content)
        print(f"Successfully updated {filepath}")

# 1. Explorer.luau
explorer_replacements = [
    (
        '\tdescendantAddedCon = game.DescendantAdded:Connect(safeCallback(addObject))\n\tdescendantRemovingCon = game.DescendantRemoving:Connect(safeCallback(removeObject))',
        '\tdescendantAddedCon = Main.RegisterConnection(game.DescendantAdded:Connect(safeCallback(addObject)))\n\tdescendantRemovingCon = Main.RegisterConnection(game.DescendantRemoving:Connect(safeCallback(removeObject)))'
    ),
    (
        '\t\t\titemChangedCon = game.ItemChanged:Connect(safeCallback(function(obj,prop)\n\t\t\t\tif prop == "Parent" and nodes[obj] then\n\t\t\t\t\tmoveObject(obj)\n\t\t\t\telseif prop == "Name" and nodes[obj] then\n\t\t\t\t\tnodes[obj].NameWidth = nil\n\t\t\t\tend\n\t\t\tend))\n\t\telse\n\t\t\titemChangedCon = game.ItemChanged:Connect(safeCallback(function(obj,prop)\n\t\t\t\tif prop == "Parent" and nodes[obj] then\n\t\t\t\t\tmoveObject(obj)\n\t\t\t\tend\n\t\t\tend))',
        '\t\t\titemChangedCon = Main.RegisterConnection(game.ItemChanged:Connect(safeCallback(function(obj,prop)\n\t\t\t\tif prop == "Parent" and nodes[obj] then\n\t\t\t\t\tmoveObject(obj)\n\t\t\t\telseif prop == "Name" and nodes[obj] then\n\t\t\t\t\tnodes[obj].NameWidth = nil\n\t\t\t\tend\n\t\t\tend)))\n\t\telse\n\t\t\titemChangedCon = Main.RegisterConnection(game.ItemChanged:Connect(safeCallback(function(obj,prop)\n\t\t\t\tif prop == "Parent" and nodes[obj] then\n\t\t\t\t\tmoveObject(obj)\n\t\t\t\tend\n\t\t\tend)))'
    ),
    (
        '\tExplorer.ViewNode = function(node)',
        '\tExplorer.Uninit = function()\n\t\tif descendantAddedCon then descendantAddedCon:Disconnect() descendantAddedCon = nil end\n\t\tif descendantRemovingCon then descendantRemovingCon:Disconnect() descendantRemovingCon = nil end\n\t\tif itemChangedCon then itemChangedCon:Disconnect() itemChangedCon = nil end\n\tend\n\n\tExplorer.ViewNode = function(node)'
    )
]
replace_in_file("Modules/Explorer.luau", explorer_replacements)

# 2. ActivityMap.luau
activity_replacements = [
    (
        '\t\tcons[#cons + 1] = game.DescendantAdded:Connect(function(obj) push("added", obj) end)\n\t\tcons[#cons + 1] = game.DescendantRemoving:Connect(function(obj) push("removed", obj) end)',
        '\t\tcons[#cons + 1] = Main.RegisterConnection(game.DescendantAdded:Connect(function(obj) push("added", obj) end))\n\t\tcons[#cons + 1] = Main.RegisterConnection(game.DescendantRemoving:Connect(function(obj) push("removed", obj) end))'
    ),
    (
        '\tActivityMap.Start, ActivityMap.Stop = start, stop\n\treturn ActivityMap\nend',
        '\tActivityMap.Start, ActivityMap.Stop = start, stop\n\tActivityMap.Uninit = function()\n\t\tstop()\n\tend\n\treturn ActivityMap\nend'
    )
]
replace_in_file("Modules/ActivityMap.luau", activity_replacements)

# 3. RuntimeInspector.luau
inspector_replacements = [
    (
        '\tRuntimeInspector.StartRemoteLogger, RuntimeInspector.StopRemoteLogger = startRemoteLogger, stopRemoteLogger\n\tRuntimeInspector.StartRakNet, RuntimeInspector.StopRakNet = startRakNet, stopRakNet\n\tRuntimeInspector.Clear, RuntimeInspector.GetBuffers = clearData, function() return buffers end\n\treturn RuntimeInspector\nend',
        '\tRuntimeInspector.StartRemoteLogger, RuntimeInspector.StopRemoteLogger = startRemoteLogger, stopRemoteLogger\n\tRuntimeInspector.StartRakNet, RuntimeInspector.StopRakNet = startRakNet, stopRakNet\n\tRuntimeInspector.Clear, RuntimeInspector.GetBuffers = clearData, function() return buffers end\n\tRuntimeInspector.Uninit = function()\n\t\tstopRemoteLogger()\n\t\tstopRakNet()\n\tend\n\treturn RuntimeInspector\nend'
    )
]
replace_in_file("Modules/RuntimeInspector.luau", inspector_replacements)

# 4. Plugins/RemoteSpy.luau
rspy_replacements = [
    (
        '\t\tlocal da_con = game.DescendantAdded:Connect(function(inst)',
        '\t\tlocal da_con = Main.RegisterConnection(game.DescendantAdded:Connect(function(inst)'
    ),
    (
        '\t\tlocal ok, con = pcall(function()\n\t\t\treturn inst[sig]:Connect(function(...)\n\t\t\t\tadd_log("in", inst, sig, table.pack(...))\n\t\t\t\tend)\n\t\t\tend)',
        '\t\tlocal ok, con = pcall(function()\n\t\t\treturn Main.RegisterConnection(inst[sig]:Connect(function(...)\n\t\t\t\tadd_log("in", inst, sig, table.pack(...))\n\t\t\t\tend))\n\t\t\tend)'
    ),
    (
        '\treturn spy\nend\n\nreturn {\n\tInitDeps      = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain          = main,\n\tPluginData    = plugin_data,\n}',
        '\tspy.Uninit = function()\n\t\tstop()\n\tend\n\treturn spy\nend\n\nreturn {\n\tInitDeps      = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain          = main,\n\tCleanUp       = function() pcall(stop) end,\n\tPluginData    = plugin_data,\n}'
    )
]
replace_in_file("Plugins/RemoteSpy.luau", rspy_replacements)

# 5. Plugins/HttpSpy.luau
hspy_replacements = [
    (
        '\treturn spy\nend\n\nreturn {\n\tInitDeps      = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain          = main,\n\tPluginData    = plugin_data,\n}',
        '\tspy.Uninit = function()\n\t\tstop()\n\tend\n\treturn spy\nend\n\nreturn {\n\tInitDeps      = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain          = main,\n\tCleanUp       = function() pcall(stop) end,\n\tPluginData    = plugin_data,\n}'
    )
]
replace_in_file("Plugins/HttpSpy.luau", hspy_replacements)

# 6. Plugins/MetatableHookManager.luau
hook_manager_replacements = [
    (
        '\treturn manager\nend\n\nreturn {\n\tInitDeps = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain = main,\n\tPluginData = plugin_data,\n}',
        '\tmanager.Uninit = function()\n\t\tactive = false\n\t\tpaused = false\n\tend\n\treturn manager\nend\n\nreturn {\n\tInitDeps = initDeps,\n\tInitAfterMain = initAfterMain,\n\tMain = main,\n\tCleanUp = function() active = false paused = false end,\n\tPluginData = plugin_data,\n}'
    )
]
replace_in_file("Plugins/MetatableHookManager.luau", hook_manager_replacements)
