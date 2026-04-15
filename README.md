# 自动化工作流（Codex 多代理编排）

这个仓库提供一套可执行的主代理编排工作流，用于把需求拆分、执行、测试、验收、回写状态串成闭环。

适用场景：

1. 你希望主 AGENT 持续接收需求并调度子 AGENT。
2. 你希望所有任务状态集中管理在 `tasks.json`。
3. 你希望有可追踪的测试证据和交付报告（`logs/`、`reports/`）。

## 仓库结构

1. `AGENTS.md`: 主/子/测试 AGENT 的角色规则与调度原则。
2. `tasks.json`: 任务与请求的状态中心（唯一事实源）。
3. `scripts/`: 工作流脚本（状态、拆解、校验、验收、总结）。
4. `prompts/`: 给不同角色 AGENT 的提示词模板。
5. `reports/`: 自动生成的计划、提示词和汇总报告。
6. `logs/`: 执行日志与质量门日志。
7. `docs/`: 设计说明、运行手册和背景资料。

## 快速开始（PowerShell）

### 1) 接收新需求（推荐入口）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-RequestWorkflow.ps1 -Request "你的需求描述"
```

这会自动执行：`Status -> Validate -> (必要时)Baseline -> Auto-PlanTasks -> Next`。

### 2) 常用命令

```powershell
# 查看任务与请求状态
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-Workflow.ps1 -Action Status

# 校验 tasks.json 约束
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-Workflow.ps1 -Action Validate

# 追加新需求并自动拆任务
powershell -ExecutionPolicy Bypass -File .\scripts\Auto-PlanTasks.ps1 -Request "继续新增 xxx"

# 选择下一个可执行任务并生成 handoff prompt
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-Workflow.ps1 -Action Next
```

### 3) 设计系统能力（已合并 awesome-design-md）

```powershell
# 查看可用 DESIGN profile（从 awesome-design-md 清单解析）
powershell -ExecutionPolicy Bypass -File .\scripts\Get-DesignCatalog.ps1

# 导入某个 profile 的 DESIGN.md / preview 文件
powershell -ExecutionPolicy Bypass -File .\scripts\Import-DesignProfile.ps1 -Profile vercel -SetProjectDesign
```

说明：

1. `Import-DesignProfile` 会把设计资料下载到 `design/awesome-design-md/<profile>/`。
2. 使用 `-SetProjectDesign` 会同步覆盖项目根 `DESIGN.md`（可配 `-Force` 强制覆盖）。
3. 当请求涉及前端/UI 时，工作流会自动把 `DESIGN.md` 纳入子任务上下文。

### 4) DESIGN 使用策略（推荐）

1. 默认使用第一批常用风格（当前项目根 `DESIGN.md`）。
2. 仅在 UI 方向不满意且需要大幅改版时，切换到第二批 profile。
3. 切换时只替换项目根 `DESIGN.md`，其余设计库保留作为候选。

切换命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Import-DesignProfile.ps1 -Profile <profile> -SetProjectDesign -Force
```

## 文档阅读顺序

建议先读这 3 篇：

1. [docs/07-成熟版运行手册.md](docs/07-成熟版运行手册.md)
2. [docs/09-统一任务拆解方案.md](docs/09-统一任务拆解方案.md)
3. [docs/03-tasks-json规范.md](docs/03-tasks-json规范.md)

完整导航见：[docs/README.md](docs/README.md)

## 协作注意事项

1. `tasks.json` 的状态回写必须串行执行，避免并发覆盖。
2. 默认不允许 `in_progress` 任务出现 scope 冲突。
3. 只对已验收通过的结果做最终交付总结。
4. 编程开发优先：代码类请求会自动补齐测试任务，形成 implementation -> testing -> acceptance 闭环。
