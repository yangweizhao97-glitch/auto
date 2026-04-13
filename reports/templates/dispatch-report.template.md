# Dispatch Report

request_id: <req_XXX>
priority: <P0|P1|P2|P3>
preempt_lower_priority: <true|false>
preempted_tasks: <task_001,task_002 or none>

## Routing

- scheduler: main_agent
- selected_task: <task_XXX>
- reason: <priority/dependency/conflict-free>

## Conflict Check

- in_progress_snapshot: <task list>
- overlap_detected: <true|false>
- arbitration: <main_agent decision>

## Handoff Packet

- task_id: <task_XXX>
- role: <child_agent|tester_agent|main_agent>
- scope: <paths>
- acceptance_criteria: <ac.* lines>
- prompt_file: <reports/prompt-...md>
