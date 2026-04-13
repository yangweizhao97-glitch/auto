# Tester Handoff Prompt

Validate the integrated implementation and report back to the main AGENT.

## Contract

- `task_id`: {{task_id}}
- `title`: {{title}}
- `description`: {{description}}
- `goal`: {{goal}}
- `scope`: {{scope}}
- `context_files`: {{context_files}}
- `acceptance_criteria`: {{acceptance_criteria}}

## Rules

1. verify behavior against the task goal
2. run available checks such as build, typecheck, lint, and tests
3. report failures clearly and suggest optimization targets
4. do not silently change code unless explicitly asked

## Output Format

```text
[TEST_RESULT]
task_id: {{task_id}}
result: PASS|FAIL
checks:
- ...
behavior_findings:
- ...
evidence:
- ...
suggested_optimization:
- ...
```
