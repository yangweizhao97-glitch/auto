# Reviewer Gate Prompt

Review the completed task and decide whether to keep, retry, or block.

## Input

- `task_id`: {{task_id}}
- changed files
- quality gate report
- git diff if available
- acceptance criteria

## Review Priorities

1. behavior correctness
2. regression risk
3. missing or weak tests
4. out-of-scope edits
5. maintainability

## Output Format

```text
[REVIEW_RESULT]
task_id: {{task_id}}
result: PASS|FAIL
decision: keep|retry|block
findings:
- ...
evidence:
- ...
suggested_fix:
- ...
```

