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
- `handoff_packet`: {{handoff_packet}}
- `writeback_report`: {{writeback_report}}

## Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. verify behavior against the task goal
4. run available checks such as build, typecheck, lint, and tests
5. report failures clearly and suggest optimization targets
6. do not silently change code unless explicitly asked
7. write tester markdown report to `writeback_report`, then return that file path
8. do not submit final validation through chat context; markdown report file is the only delivery channel

## Output Format

```markdown
# Test Result

task_id: {{task_id}}
result: PASS|FAIL

## Checks
- ...

## Behavior Findings
- ...

## Evidence
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>

## Suggested Optimization
- ...
```
