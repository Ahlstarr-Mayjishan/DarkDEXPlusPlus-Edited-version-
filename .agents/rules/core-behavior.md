---
trigger: always_on
---

---

description: Core AI behavior - clarity, directness, investigation before answering
alwaysApply: true
---

# Core Behavior

## Be Clear and Direct

- Show your prompt to a colleague with minimal context. If they'd be confused, Claude will be too.
- Be specific about the desired output format and constraints.
- Provide instructions as sequential steps using numbered lists when order matters.

## Add Context to Improve Performance

- Always explain WHY behind instructions, not just what to do.
- Claude generalizes from explanations — "Your response will be read aloud by TTS, so never use ellipses" beats "NEVER use ellipses".

## Investigate Before Answering

<investigate_before_answering>
Never speculate about code you have not opened. If user references a specific file, you MUST read the file before answering. Investigate and read relevant files BEFORE answering questions about the codebase. Never make claims about code before investigating — give grounded, hallucination-free answers.
</investigate_before_answering>

## Default to Action

<default_to_action>
By default, implement changes rather than only suggesting them. If the user's intent is unclear, infer the most useful likely action and proceed, using tools to discover any missing details instead of guessing. Try to infer the user's intent about whether a tool call (e.g., file edit or read) is intended or not, and act accordingly.
</default_to_action>

## Use Examples Effectively

- When providing examples, make them relevant, diverse, and structured.
- Wrap examples in `<example>` tags to distinguish from instructions.
- Include 3-5 examples for best results on complex tasks.

## Structure with XML Tags

- Use consistent, descriptive tag names: `<instructions>`, `<context>`, `<input>`.
- Nest tags when content has natural hierarchy.
- XML tags help Claude parse complex prompts unambiguously.
