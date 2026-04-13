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

## Rules

1. modify only files inside `scope`
2. prefer the simplest change that satisfies the goal
3. report unknowns instead of guessing
4. run local checks if available

## Output Format

```text
[WORKER_RESULT]
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

