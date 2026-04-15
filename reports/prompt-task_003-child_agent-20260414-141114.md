# Worker Handoff Prompt

Execute a single coding task using the contract below.

## Contract

- `task_id`: task_003
- `title`: Update Developer Docs
- `description`: Implement request req_001 for area 'docs': 目前工作流的agents后续，每次完成任务都要写成md文档后，发给主AGENT让他来处理。让子agent通过读取md文档来获取信息 而不是上下文
- `goal`: Implement request req_001 for area 'docs': 目前工作流的agents后续，每次完成任务都要写成md文档后，发给主AGENT让他来处理。让子agent通过读取md文档来获取信息 而不是上下文
- `scope`: docs/, README.md
- `context_files`: AGENTS.md, tasks.json, prompts/worker-handoff.md
- `acceptance_criteria`: ac.scope_only: changed files stay under docs/ or README.md; ac.docs_match: docs evidence reflects implemented behavior; ac.validation: include doc review result in evidence
- `handoff_packet`: C:\Users\admin\Desktop\自动化工作流\reports\handoff\packet-task_003-child_agent-20260414-141114.md
- `writeback_report`: C:\Users\admin\Desktop\自动化工作流\reports\results\result-task_003-child_agent-20260414-141114.md

## Rules

1. read `handoff_packet` first and use it as primary task input
2. do not rely on prior conversation context for task details
3. modify only files inside `scope`
4. prefer the simplest change that satisfies the goal
5. report unknowns instead of guessing
6. run local checks if available
7. write the final result into `writeback_report` as markdown, then return that path to main AGENT

## Output Format

```markdown
# Worker Result

task_id: task_003

## Changed Files
- ...

## Summary
- ...

## Validation
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>

## Risks
- ...
```

