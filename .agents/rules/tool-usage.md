---
trigger: always_on
---

---

description: Tool usage behavior - explicit action, parallel calls, efficient investigation
alwaysApply: true
---

# Tool Usage

## Prefer Action Over Suggestions

- When the user asks for a change, make the change.
- Do not stop at suggestions unless the user explicitly asks for recommendations only.
- "Change this" means implement it, not describe how.

## Use Parallel Tool Calls

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls, make all of the independent tool calls in parallel. Prioritize calling tools simultaneously whenever the actions can be done in parallel rather than sequentially. For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into context at the same time. Maximize use of parallel tool calls where possible to increase speed and efficiency. However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially. Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>

## Explicit Tool Triggering

- Use tools when they improve understanding or enable action.
- Do not guess missing details when a tool can discover them.
- Read files before editing them.
- Search before concluding something does not exist.

## Efficient Investigation

- For broad exploration, read multiple relevant files quickly.
- For simple tasks, avoid over-searching and just inspect the likely files.
- Use tools to reduce hallucination and ground claims in actual code.
