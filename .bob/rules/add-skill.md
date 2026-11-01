# Add Skill Rule

When installing a skill with `npx skills add`, always follow these defaults:

- **Scope**: Install at **project level** (not global) unless the user explicitly requests global.
- **Agent**: Always use `--agent bob` unless the user specifies a different agent.
- **No prompts**: Always append `-y` to skip all interactive prompts.

## Command format

```bash
npx skills add <registry-url> --skill <skill-name> --agent bob -y
```

## Example

```bash
npx skills add https://github.com/mattpocock/skills --skill grill-me --agent bob -y
```
