# Test Child Prompt

Implement a single testing task.

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

## Testing Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. focus on automated verification
4. keep test intent easy to understand from changed files
5. report any missing hooks or seams that block testing
6. write final markdown report to `writeback_report`, then return that file path

## Output Format

```markdown
# Test Child Result

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
