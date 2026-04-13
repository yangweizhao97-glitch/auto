# Test Report

request_id: <req_XXX>
task_id: <task_XXX>
overall: <PASS|FAIL>

## Checks

- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<optional>
- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<optional>

## Behavioral Verification

- ac_id: <ac.*>
- expected: <expected behavior>
- actual: <observed behavior>
- result: <pass|fail>
- evidence: <artifact path or url>

## Decision Input

- recommended_action: <accept|retry|block>
- failure_reason: <empty when pass>
- retry_targets: <task ids or none>
