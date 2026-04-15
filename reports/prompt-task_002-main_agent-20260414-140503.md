# Planner Prompt

Use this prompt when refining a feature request into implementation tasks.

## Input

- user goal
- current repository state
- `tasks.json`

## Instructions

1. split the request into the smallest reviewable tasks
2. keep dependencies acyclic and minimal
3. make acceptance criteria measurable
4. avoid speculative tasks
5. prefer tasks that can be completed and reviewed independently

## Output Format

```text
[PLAN]
goal:
tasks:
- id:
  title:
  description:
  dependencies:
  owner_role:
  scope:
  acceptance_criteria:
risks:
- ...
```


