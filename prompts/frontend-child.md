# Frontend Child Prompt

Implement a single frontend task.

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

## Frontend Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. change only UI-facing files in `scope`
4. keep behavior intentional and easy to verify
5. call out edge cases that still need QA
6. write final markdown report to `writeback_report`, then return that file path

## Output Format

```markdown
# Frontend Result

task_id: {{task_id}}

## Changed Files
- ...

## Summary
- ...

## Validation
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>

## Risks
- ...
```
