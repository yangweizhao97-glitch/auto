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

## Testing Rules

1. focus on automated verification
2. keep test intent easy to understand from changed files
3. report any missing hooks or seams that block testing

## Output Format

```text
[TEST_CHILD_RESULT]
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

