# Task Handoff Packet

generated_at: 2026-04-14T14:12:08.6127362+08:00
task_id: task_004
request_id: req_001
role: tester_agent
phase: testing

## Request Goal
目前工作流的agents后续，每次完成任务都要写成md文档后，发给主AGENT让他来处理。让子agent通过读取md文档来获取信息 而不是上下文

## Task Contract
- title: Tester Validation
- description: Tester AGENT validates request req_001 and returns findings to the main AGENT.
- scope: logs/, reports/, tasks.json
- context_files: AGENTS.md, tasks.json, prompts/tester-handoff.md
- acceptance_criteria: ac.quality_checks: build/typecheck/lint/test results are recorded; ac.report_format: tester output includes pass_or_fail, checks, findings, and evidence; ac.evidence_schema: evidence lines follow cmd|result|log format

## Context Files
- AGENTS.md
- tasks.json
- prompts/tester-handoff.md

## Dependency Snapshot
### task_003 - Update Developer Docs
- status: todo
- failure_reason: <none>
- evidence:
  - <none>
- md_artifacts:
  - <none>

## Execution Rules
- Read this packet first and treat it as the primary handoff source.
- Do not rely on prior chat context; if details are missing, report the gap in result markdown.
- Write the final task result to: C:\Users\admin\Desktop\自动化工作流\reports\results\result-task_004-tester_agent-20260414-141208.md
- Return the markdown report path to the main AGENT.
