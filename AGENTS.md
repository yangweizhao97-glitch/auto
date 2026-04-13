# Main-Agent Dispatch Workflow

## Goal

This workflow exists to improve development efficiency through delegation:

1. the main AGENT receives the request
2. the user may submit additional requests while earlier tasks are still in progress
3. the main AGENT splits work into child tasks
4. child AGENTs implement the assigned changes
5. a tester AGENT validates the combined result
6. the main AGENT accepts the result or sends it back for optimization
7. only accepted work is summarized back to the user

## Default Intake Behavior

For every new user requirement, the workflow must start automatically.
Do not wait for a special trigger sentence from the user.

Mandatory sequence:

1. run `scripts/Invoke-Workflow.ps1 -Action Status`
2. run `scripts/Invoke-Workflow.ps1 -Action Validate`
3. if baseline task is not done, run `scripts/Invoke-Workflow.ps1 -Action Baseline`
4. run `scripts/Auto-PlanTasks.ps1 -Request "<user requirement>"`
5. run `scripts/Invoke-Workflow.ps1 -Action Next`
6. continue child implementation, tester validation, and main acceptance loop

Policy:

1. do not ask the user to repeat workflow instructions unless execution is blocked
2. assume workflow mode is always on in this repository
3. keep `tasks.json` writes serialized by the main AGENT

## Priority And Preemption

Priority levels:

1. `P0` critical
2. `P1` high
3. `P2` normal
4. `P3` low

Rules:

1. dispatch order is `P0 -> P1 -> P2 -> P3`
2. a new request can preempt lower-priority in-progress tasks only when `preempt_lower_priority=true`
3. preemption reverts target tasks to `todo` and records a reason in `failure_reason`
4. non-preemptible tasks must not be paused automatically

## Roles

### `main_agent`

Responsibilities:

1. understand the request
2. keep accepting additional user requests without overwriting earlier requests
3. split work by deliverable, code boundary, and acceptance method
4. decide which tasks can run in parallel
5. dispatch tasks to child AGENTs
6. collect child results
7. hand the result to the tester AGENT
8. decide `accept`, `retry`, or `block`
9. write the final summary

### `child_agent`

Responsibilities:

1. implement exactly one assigned task
2. modify only the allowed scope
3. return changed files, summary, validation notes, and risks
4. stop and report if the scope is insufficient

### `tester_agent`

Responsibilities:

1. verify the integrated result after child implementation
2. run available build, typecheck, lint, and test checks
3. validate the user-facing behavior against acceptance criteria
4. return a structured test result to the main AGENT

## Task Splitting Rules

The main AGENT must split tasks in this order:

1. by deliverable
2. by code boundary
3. by acceptance method
4. by dependency only after the above are clear

This means:

1. `dependencies` control order
2. `skills` describe execution or testing style
3. the real split is based on what can be implemented and verified independently

## Dispatch Rules

1. independent implementation tasks should be dispatched to child AGENTs
2. child tasks may run in parallel when file scopes do not overlap unsafely
3. every delegated task must include:
   - `task_id`
   - `request_id`
   - `parent_task_id`
   - `goal`
   - `scope`
   - `context_files`
   - `acceptance_criteria`
4. the main AGENT owns all final task state changes
5. writes to `tasks.json` should be serialized by the main AGENT; do not run multiple status-write scripts in parallel

## Conflict Resolution

When scope conflicts happen:

1. main AGENT is the final arbiter
2. conflicting tasks cannot both be `in_progress` unless `allow_scope_overlap=true`
3. merge order is priority-first, then request creation time
4. lower-priority task returns to `todo` with conflict evidence
5. if conflict repeats beyond retry limit, task becomes `blocked`

## Test And Acceptance Loop

After child AGENTs finish:

1. the tester AGENT runs checks and returns a test report
2. the main AGENT reads the report and chooses:
   - `accept`
   - `retry`
   - `block`
3. if the result is not acceptable, the main AGENT sends the work back for optimization
4. only accepted work moves to final summary

## Verification Checks

The tester AGENT or main AGENT should run these checks when available:

1. build
2. typecheck
3. lint
4. tests
5. diff review

## State Rules

Allowed task states:

1. `todo`
2. `in_progress`
3. `done`
4. `blocked`

Rules:

1. a task can start only when its dependencies are `done`
2. retries increment after failed acceptance
3. retries cannot exceed `max_retries`; overflow transitions to `blocked`
4. the main AGENT updates `status`, `retries`, `failure_reason`, and `evidence`
5. each new user request should be appended as a new request group instead of overwriting existing tasks

## Acceptance Criteria Contract

Every acceptance criterion must be machine-checkable text using:

1. `ac.<id>: <condition>`

Examples:

1. `ac.scope_only: changed files stay inside declared scope`
2. `ac.test_api_200: GET /api/game returns 200`
3. `ac.test_case_exists: tests/game-score.spec.ts is updated`

## Evidence Contract

Evidence should use one line per check:

1. `cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>`

`artifact` is optional but recommended.

## Required Output

### Child AGENT Output

1. changed files
2. implementation summary
3. validation notes
4. remaining risks

### Tester AGENT Output

1. overall pass or fail
2. checks performed
3. behavior findings
4. evidence
5. suggested optimization if failed

## Completion Condition

The workflow is complete only when:

1. child work is implemented
2. tester validation passes
3. the main AGENT accepts the result
4. the final summary is produced
