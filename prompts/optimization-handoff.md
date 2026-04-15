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
- `handoff_packet`: {{handoff_packet}}
- `writeback_report`: {{writeback_report}}

## Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. focus only on the failed findings
4. preserve good existing work when possible
5. explain exactly what changed to address the failure
6. write optimization markdown report to `writeback_report`, then return that file path

## Output Format

```markdown
# Optimization Result

task_id: {{task_id}}

## Changed Files
- ...

## Fixes
- ...

## Validation
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>

## Remaining Risks
- ...
```
