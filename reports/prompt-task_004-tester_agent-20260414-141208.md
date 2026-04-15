# Tester Handoff Prompt

Validate the integrated implementation and report back to the main AGENT.

## Contract

- `task_id`: task_004
- `title`: Tester Validation
- `description`: Tester AGENT validates request req_001 and returns findings to the main AGENT.
- `goal`: Tester AGENT validates request req_001 and returns findings to the main AGENT.
- `scope`: logs/, reports/, tasks.json
- `context_files`: AGENTS.md, tasks.json, prompts/tester-handoff.md
- `acceptance_criteria`: ac.quality_checks: build/typecheck/lint/test results are recorded; ac.report_format: tester output includes pass_or_fail, checks, findings, and evidence; ac.evidence_schema: evidence lines follow cmd|result|log format
- `handoff_packet`: C:\Users\admin\Desktop\自动化工作流\reports\handoff\packet-task_004-tester_agent-20260414-141208.md
- `writeback_report`: C:\Users\admin\Desktop\自动化工作流\reports\results\result-task_004-tester_agent-20260414-141208.md

## Rules

1. read `handoff_packet` first and treat it as the execution source
2. do not rely on prior conversation context for task details
3. verify behavior against the task goal
4. run available checks such as build, typecheck, lint, and tests
5. report failures clearly and suggest optimization targets
6. do not silently change code unless explicitly asked
7. write tester markdown report to `writeback_report`, then return that file path

## Output Format

```markdown
# Test Result

task_id: task_004
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

