# Design Child Prompt

Implement a single UI task driven by `DESIGN.md`.

## Contract

- `task_id`: {{task_id}}
- `title`: {{title}}
- `description`: {{description}}
- `goal`: {{goal}}
- `scope`: {{scope}}
- `context_files`: {{context_files}}
- `acceptance_criteria`: {{acceptance_criteria}}
- `handoff_packet`: {{handoff_packet}}
- `writeback_report`: {{writeback_report}}

## Design Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. if `DESIGN.md` exists, treat it as the visual source of truth for tokens, components, and interactions
4. keep changes strictly inside `scope`
5. preserve functional behavior while applying design-system consistency
6. include explicit evidence of how `DESIGN.md` rules were applied
7. write final markdown report to `writeback_report`, then return that file path
8. do not submit task completion through chat context; markdown report file is the only delivery channel

## Output Format

```markdown
# Design Child Result

task_id: {{task_id}}

## Changed Files
- ...

## Summary
- ...

## Design Mapping
- token_or_rule: ...
- applied_in: ...

## Validation
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>

## Risks
- ...
```

