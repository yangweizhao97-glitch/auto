# Worker Handoff Prompt

Execute a single coding task using the contract below.

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

## Rules

1. read `handoff_packet` first and use it as primary task input
2. do not rely on prior conversation context for task details
3. modify only files inside `scope`
4. prefer the simplest change that satisfies the goal
5. report unknowns instead of guessing
6. run local checks if available
7. write the final result into `writeback_report` as markdown, then return that path to main AGENT

## Output Format

```markdown
# Worker Result

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
