# Backend Child Prompt

Implement a single backend task.

## Contract

- `task_id`: {{task_id}}
- `title`: {{title}}
- `description`: {{description}}
- `goal`: {{goal}}
- `scope`: {{scope}}
- `context_files`: {{context_files}}
- `acceptance_criteria`: {{acceptance_criteria}}

## Backend Rules

1. change only server-side files in `scope`
2. keep contracts and side effects explicit
3. call out schema, API, or service risks directly

## Output Format

```text
[BACKEND_RESULT]
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

