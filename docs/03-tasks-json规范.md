# tasks.json 规范（v1）

日期：2026-04-13

## 1. 顶层结构

```json
{
  "version": "1.0",
  "project": "your-project-name",
  "tasks": []
}
```

## 2. 任务字段定义

每个任务对象建议包含：

1. `id`（string，必填）：唯一任务 ID。
2. `description`（string，必填）：任务描述。
3. `status`（string，必填）：`todo | in_progress | done | blocked`。
4. `dependencies`（string[]，必填）：依赖任务 ID 列表。
5. `skills`（string[]，选填）：验收使用的 skill 标签。
6. `context_files`（string[]，选填）：执行时传给子代理的文件路径。
7. `retries`（number，必填）：当前重试次数。
8. `max_retries`（number，选填，默认 3）：最大重试次数。
9. `failure_reason`（string，选填）：最近一次失败原因。
10. `evidence`（string[]，选填）：测试结果、日志路径、截图等。
11. `updated_at`（string，选填）：ISO 时间戳。

## 3. 状态机规则

1. 初始状态必须为 `todo`。
2. 开始执行时改为 `in_progress`。
3. 验收通过改为 `done`。
4. 验收失败：
   - 若 `retries < max_retries`：回到 `todo`。
   - 若 `retries >= max_retries`：改为 `blocked`。

## 4. 依赖校验规则

任务可执行条件：

1. 自身 `status = todo`。
2. `dependencies` 中所有任务均为 `done`。

不满足任一条件，则不能启动。

## 5. 示例（推荐）

```json
{
  "version": "1.0",
  "project": "workflow-mvp",
  "tasks": [
    {
      "id": "task_001",
      "description": "拆分需求并补全任务清单",
      "status": "done",
      "dependencies": [],
      "skills": ["planning"],
      "context_files": ["docs/01-Codex自动化工作流方案.md"],
      "retries": 0,
      "max_retries": 3,
      "evidence": ["docs/任务拆分记录.md"],
      "updated_at": "2026-04-13T14:40:00+08:00"
    },
    {
      "id": "task_002",
      "description": "实现任务调度逻辑",
      "status": "todo",
      "dependencies": ["task_001"],
      "skills": ["implementation", "test"],
      "context_files": ["src/scheduler.ts", "tasks.json"],
      "retries": 0,
      "max_retries": 3
    }
  ]
}
```

