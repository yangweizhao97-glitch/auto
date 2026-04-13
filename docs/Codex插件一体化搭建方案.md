# VSCode Codex 插件一体化搭建方案（单文档）

日期：2026-04-13

## 1. 目标

在 VSCode 的 Codex 插件中跑通自动化开发工作流：

1. 任务拆分和依赖编排。
2. 主代理调度子代理执行。
3. skills 验收并回写任务状态。

## 2. 你只需要这 3 个文件

项目根目录：

```text
.
├─ AGENTS.md
├─ tasks.json
└─ docs/
   └─ Codex插件一体化搭建方案.md
```

## 3. `AGENTS.md` 最小模板

```md
# AGENTS Rules

## Workflow
- tasks.json 是唯一任务源
- 仅执行 dependencies 全满足的任务
- 每步执行后必须回写 tasks.json

## Status
- 只允许: todo -> in_progress -> done/blocked
- 失败重试上限: 3

## Sub-Agent Context
- 必须传: task_id, goal, scope, context_files, acceptance_criteria

## Acceptance
- 必须输出: PASS/FAIL, evidence, reason(失败时), suggested_fix(失败时)
```

## 4. `tasks.json` 最小模板

```json
{
  "version": "1.0",
  "project": "workflow-mvp",
  "tasks": [
    {
      "id": "task_001",
      "description": "拆分任务并校验依赖规则",
      "status": "todo",
      "dependencies": [],
      "skills": ["planning"],
      "context_files": ["docs/Codex插件一体化搭建方案.md"],
      "retries": 0,
      "max_retries": 3
    },
    {
      "id": "task_002",
      "description": "执行开发任务并产出变更",
      "status": "todo",
      "dependencies": ["task_001"],
      "skills": ["implementation", "test"],
      "context_files": ["src/"],
      "retries": 0,
      "max_retries": 3
    },
    {
      "id": "task_003",
      "description": "运行验收并回写状态",
      "status": "todo",
      "dependencies": ["task_002"],
      "skills": ["review", "qa"],
      "context_files": ["tasks.json"],
      "retries": 0,
      "max_retries": 3
    }
  ]
}
```

## 5. 子代理下发模板（主代理用）

```text
执行任务: {task_id}
目标: {goal}
修改范围: {scope}
上下文文件: {context_files}
验收标准: {acceptance_criteria}

输出要求:
1) 修改文件列表
2) 关键改动说明
3) 验证结果
4) 风险与待确认
```

## 6. 验收回写规则

1. PASS:
   - `status = done`
   - 写入 `evidence`
2. FAIL:
   - `retries += 1`
   - 写入 `failure_reason`
   - 若 `retries < max_retries`，`status = todo`
   - 否则 `status = blocked`

## 7. 在 VSCode Codex 里直接发这段指令

```text
按 AGENTS.md 规范执行当前工作流：
1) 读取 tasks.json，找出 dependencies 满足的 todo 任务；
2) 逐任务执行，必要时启动子代理并传完整上下文；
3) 每个任务执行后做 skills 验收，输出 PASS/FAIL 与证据；
4) 按规则回写 tasks.json（status/retries/failure_reason/evidence）；
5) 全部完成后输出总结（done/blocked 数量、关键失败原因、下一步建议）。
```

## 8. 为什么之前写了两份

之前拆分是为了评审方便：

1. 一份讲“做什么”（方案）。
2. 一份讲“怎么做”（操作步骤）。

你现在明确是 VSCode Codex 插件实操场景，用这份单文档即可，不需要分开看。

