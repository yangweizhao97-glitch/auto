# 子代理与 Skills 验收协议（v1）

日期：2026-04-13

## 1. 子代理启动协议

主代理在启动子代理时，必须传递以下上下文：

1. `task_id`：当前任务 ID。
2. `goal`：本次明确目标（一句话）。
3. `scope`：允许修改的文件范围。
4. `handoff_packet`：任务交接 markdown 文件路径（主输入源）。
5. `input_context`：相关代码片段或文件路径（可选补充，不是主输入源）。
6. `acceptance_criteria`：验收标准（可测、可判断）。
7. `writeback_report`：子代理完成后要写入的 markdown 报告路径。
8. `output_format`：要求子代理返回的结构。

推荐消息模板：

```text
你负责执行任务 {task_id}。
目标：{goal}
可修改范围：{scope}
交接文档：{handoff_packet}
补充上下文文件：{input_context}
验收标准：{acceptance_criteria}
结果回写路径：{writeback_report}
请先读取交接文档执行，不要依赖历史对话上下文。
请输出：
1) 修改文件列表
2) 关键变更说明
3) 本地验证结果
4) 风险与待确认项
```

## 2. Skills 验收协议

每次任务完成后，必须触发验收。验收输出必须结构化：

1. `result`：`PASS` 或 `FAIL`
2. `checks`：执行的检查项
3. `evidence`：日志、截图、测试结果
4. `reason`：失败原因（若失败）
5. `suggested_fix`：建议修复动作（若失败）

推荐验收模板：

```text
[ACCEPTANCE]
task_id: {task_id}
skill: {skill_name}
result: PASS|FAIL
checks:
- ...
- ...
evidence:
- ...
reason: ...
suggested_fix: ...
```

补充要求：

1. 验收结果应优先写入 markdown 报告文件并返回路径。
2. evidence 中建议附加 `artifact=<markdown-report-path>`。

## 3. 回写规则（tasks.json）

1. 验收 PASS：
   - `status = done`
   - 附加 `evidence`
2. 验收 FAIL：
   - `retries += 1`
   - 写入 `failure_reason`
   - 若未超限：`status = todo`
   - 若超限：`status = blocked`

## 4. 主代理控制逻辑（伪代码）

```text
while exists(task.status in [todo, in_progress]):
  ready_tasks = todo tasks where all dependencies == done
  if ready_tasks is empty:
    break
  for task in ready_tasks:
    set task.status = in_progress
    spawn worker(task_context)
    run acceptance(skill_set)
    if PASS:
      set task.status = done
    else:
      task.retries += 1
      if task.retries >= task.max_retries:
        set task.status = blocked
      else:
        set task.status = todo
    persist tasks.json
```

## 5. 最小技能映射建议

1. 任务切割类：`planning`
2. 编码实现类：`implementation`, `test`
3. 验收评审类：`review`, `qa`
4. 文档产出类：`docs`

## 6. 常见失败与处理

1. 子代理没有拿到上下文：
   - 优先检查 `handoff_packet` 是否存在并可读，再补充 `context_files`。
2. 验收标准不清晰导致反复失败：
   - 将标准改成可量化检查项（如“测试通过 3 项”）。
3. 依赖链卡死：
   - 检查前置任务是否误标为 `done` 或长期 `blocked`。
