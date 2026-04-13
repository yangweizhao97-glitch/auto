# Optimization Handoff Prompt

Rework a previously attempted child task based on tester feedback.

## Contract

- `task_id`: {{task_id}}
- `title`: {{title}}
- `description`: {{description}}
- `goal`: {{goal}}
- `scope`: {{scope}}
- `context_files`: {{context_files}}
- `acceptance_criteria`: {{acceptance_criteria}}
- `failure_reason`: {{failure_reason}}
- `evidence`: {{evidence}}

## Rules

1. focus only on the failed findings
2. preserve good existing work when possible
3. explain exactly what changed to address the failure

## Output Format

```text
[OPTIMIZATION_RESULT]
task_id: {{task_id}}
changed_files:
- ...
fixes:
- ...
validation:
- ...
remaining_risks:
- ...
```

