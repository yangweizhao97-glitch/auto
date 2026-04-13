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

## Frontend Rules

1. change only UI-facing files in `scope`
2. keep behavior intentional and easy to verify
3. call out edge cases that still need QA

## Output Format

```text
[FRONTEND_RESULT]
task_id: {{task_id}}
changed_files:
- ...
summary:
- ...
validation:
- ...
risks:
- ...
```

