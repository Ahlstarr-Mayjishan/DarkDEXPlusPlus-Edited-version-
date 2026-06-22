# DEX++ Module Layout

Runtime module names remain flat (`Apps.CodeSearch`, `Apps.RuntimeInspector`, etc.).
Only the source files are grouped to make ownership easier to understand.

## Core

Shared UI, shell, settings, task control, and safety controls.

- `Theme`
- `State`
- `Lib`
- `Console`
- `SettingsWindow`
- `ControlCenter`
- `TaskRouter`
- `ThreadManager`

## Explorer

Instance browsing, object inspection, previews, serialization, and save/export tools.

- `Explorer`
- `Properties`
- `SaveInstance`
- `ModelViewer`
- `ImageViewer`
- `SoundViewer`
- `AnimationViewer`
- `ObjectLinks`
- `InstanceSerializer`
- `Clipboard`
- `Duplicate`
- `Deletion`
- `PropertyCopier`
- `PropertyRestorer`
- `Rename`
- `History`

### Explorer Context Menus

- `EditMenu`
- `NavigationMenu`
- `ObjectMenu`
- `ScriptMenu`
- `InteractionMenu`
- `PlayerMenu`
- `NilInstanceMenu`

## Search

Script/code search, source indexing, dependency/reference views, and code security review.

- `SmartDecompiler`
- `Notepad`
- `ClientIndex`
- `CodeSearch` (`Search Center` in the menu)
- `SmartSearch`
- `DependencyGraph`
- `ScriptRelations`
- `SecurityAuditor`

## Runtime

Live client observation, remote/runtime activity, property tracking, and runtime summaries.

- `RuntimeInspector` (`Runtime Monitor` in the menu)
- `RemoteUsageMap`
- `ActivityMap`
- `PropertyTracker`
- `RemoteFuzzer`
- `ClientIntelligence`
- `InspectorHub`

## Tools

IDE integration and external tooling bridges.

- `IDESync`
