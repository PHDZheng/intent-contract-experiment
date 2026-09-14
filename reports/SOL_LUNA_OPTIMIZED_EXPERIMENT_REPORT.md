# Sol 与 Luna 优化版 15 轮实验报告

## 摘要

本报告汇总 `dpipe` 15 轮顺序演化任务上，`gpt-5.6-sol` 与 `gpt-5.6-luna` 使用 Intent Contract 优化版本的实验。用户原表述中的 “aluna” 在实验目录中没有对应模型或版本，本文按实际存在的 `gpt-5.6-luna` 处理。

主要结论如下：

- Sol 的有效优化路径把 15 轮 Contract 总体积从 5,492,517 bytes 降到 376,676 bytes（-93.14%），模型输入 token 从 28,567,394 降到 8,668,433（-69.66%），成本从 $22.379521 降到 $8.428238（-62.34%）。
- 有效优化版本中，`v2-general-anchor` 的 Harbor mean reward 为 **0.6667**、10/15 轮全量通过、累计 **11,009/11,034（99.77%）**，并具有最低的本次记录成本。
- 与完整 v2 Contract 相比，compact、focused、transition-anchor 在大幅减少上下文后仍保留了接近相同的正确性；其中执行锚点修复了“代码已改但标准位置的 `dpipe` 二进制未重建”的执行断链。
- Luna 在与 Sol general-anchor 完全相同的 Contract 输入上，两次有效运行的累计通过率为 95.58% 和 94.38%，平均 94.98%；两次 Harbor reward 均为 0。平均成本为 $0.453406，但精度和跨轮完整通过能力明显低于 Sol。

## 1. 实验问题与评价口径

实验任务为 `theme_d5_w9_data_engineering_reproducibility_verification` 的 15 轮顺序开发。每轮在同一持久化工作区继续修改 Go 项目，verifier 累积检查当前轮及历史需求。

统一设置：

| 项目 | 设置 |
|---|---|
| Agent | Codex |
| 模型 | `openai/gpt-5.6-sol` 或 `openai/gpt-5.6-luna` |
| reasoning effort | medium |
| 每个 job 并发 | 1 |
| 每个有效结果的 trial 数 | 1 |
| 任务轮数 | 15 |
| Agent 指令模式 | contract-only |
| 工作区 | 跨轮持久化 |

指标含义：

- `Harbor mean reward` 是 15 个逐轮二元 reward 的平均值。一轮只有全部 case 通过才记 1。
- `累计 case 通过率` 将 15 轮所有 `CASE_RESULT` 合并计算。总 case 数为 11,034，但其中包含跨轮重复回归检查，并非 11,034 个相互独立需求。
- `Contract 总体积` 是 15 个 materialized `instruction.md` 的字节数之和，只衡量输入规格本身；`input tokens` 还包含 Agent 多轮读取代码、测试输出等上下文。
- 成本来自 Harbor 汇总的 Agent 模型调用，不包含 Intent Compiler、容器、verifier 和人工审查成本。

## 2. 优化版本演化

### 2.1 从完整状态到最小可执行状态转移

| 版本 | 每轮给 Agent 的信息 | 15轮 Contract 总大小 | round-15 大小 | 目的 |
|---|---|---:|---:|---|
| v2 full | 全部 active spec、来源原文、历史 tombstone | 5,492,517 B | 527,471 B | 完整可审计、但重复严重 |
| v2 compact | 全部 active spec，去掉重复原文和空字段 | 2,592,988 B | 260,272 B | 无损语义压缩 |
| v2 focused | 当前轮完整需求、显式依赖、其余需求索引 | 688,638 B | 45,873 B | 让注意力集中于当前变化 |
| v2 transition | 当前变化、显式依赖、前态摘要 | 369,358 B | 12,395 B | 利用持久化代码作为历史状态 |
| v2 transition-anchor | transition + 稳定执行锚点 | 376,676 B | 12,914 B | 保证构建/运行链不断裂 |
| v2 general-anchor | 将锚点规则泛化为 `build.*`/`execution.*` | 376,676 B | 12,914 B | 将任务特定锚点变成通用规则 |

本任务中 `transition-anchor` 和 `general-anchor` 生成的 15 轮 Contract 逐文件完全相同，所以两次 Sol 成绩差异只能视为运行随机性，不能归因于 prompt 内容变化。general-anchor 的贡献是实现规则的泛化，而不是本任务输入内容的进一步变化。

### 2.2 优化一：v2 replacement-grade IR

早期 v1 更接近“需求摘要台账”，字段通常只有 semantic key、简短 statement 和 value。v2 将编译目标改成可替代原 instruction 的结构化规格，每条 requirement 可包含 interface、input/output schema、algorithm、formula、default、ordering、formatting、edge case、error、example、integration 和 invariant。

它同时加入三类可验证关系：原文 clause 到 requirement 的覆盖关系、同 semantic key 的 supersession 链，以及 source round、字符 offset、原文和 SHA-256 的来源关系。这样后续压缩只改变呈现方式，不必丢掉完整审计数据。

例 1：round 5 的一句“verify 改用 BLAKE2b-256”不再只被压成一个算法名，而是生成读取文件、计算 raw-byte digest、64 位小写十六进制编码、比较以及 `VERIFIED`/`MISMATCH` 精确输出等算法和错误字段。

例 2：`transform.fill` 的 linear 策略被拆成上下锚点搜索、双锚点插值、单锚点外推、无锚点留空和 `FormatFloat` 格式要求，避免一句摘要漏掉边界行为。

代价是 full v2 的 15 轮 Contract 达 5,492,517 B，Sol 输入达 28,567,394 tokens。因此 v2 full 适合作为权威审计状态，不适合作为每轮直接重复给 Agent 的最终形态。

### 2.3 优化二：compact——删除表示冗余

compact 从同一份 v2 IR 确定性渲染，不重新调用语义模型。它保留所有非空 spec、requirement ID、semantic key、modality、source round、clause ID 和 supersession tombstone，但删除重复的 verbatim evidence、空数组/空字符串，以及每条 requirement 重复出现的 instruction hash。

例 1：full Contract 会在 `verify.checksum_behavior` 后再次逐字附上来源 clause；compact 只保留 `clauses: r005-c003,r005-c004,r005-c005`，原文仍存在权威 IR 中。

例 2：若某 requirement 的 `examples=[]`、`defaults=[]`、`notes=[]`，compact 不输出这些键；`algorithm`、`errors` 或 `formatting` 等非空字段原样保留。

效果：Contract 减少 52.79%，Sol 输入减少 38.38%，成本减少 37.98%，累计通过率和 full v2 完全相同，均为 99.77%。这说明删除的是表示冗余，而不是本任务所需语义。

### 2.4 优化三：focused——当前轮详述、历史需求索引化

focused 不再完整展开所有 active requirements。它把当前轮 operation 和 clause mapping 触及的 requirement 放入 `touched`，把这些 spec 按 ID 或 semantic key 明确引用的历史 requirement 放入 `dependencies`，两类都完整输出；其他 active requirement 只在 preservation index 中保留 modality、key、ID 和 summary；全部 tombstone 继续保留。

例 1：round 15 只完整展开 7 个 snapshot/tag 相关 requirement，另外 211 个 active requirement 以 preservation index 形式列出，因此 Agent 能看到“必须保持哪些行为”，但不会再次读取其全部算法字段。

例 2：若当前 spec 的 integration 字段引用已有 requirement 或 semantic key，该 requirement 会从 preservation index 提升到 dependency 区并完整展开，而不是仅凭词义猜测依赖。

效果：Contract 比 full v2 减少 87.46%，输入 token 减少 67.74%，成本减少 60.66%，正确性仍为 99.77%。

### 2.5 优化四：transition——把完整状态改成状态转移

focused 仍会打印全部历史需求索引；transition 进一步利用“15 轮共享同一持久化代码库”这一条件，只给出 touched requirement、显式 dependency、当轮 supersession 和 prior-state digest。未变化需求由现有代码与完整回归测试承载，不再逐条打印。

例 1：round 15 的输入只展开 7 个本轮变化、0 个显式依赖，并用 `Preserved active requirements: 210` 及 SHA-256 表示未变化状态，而不是打印 210 行 preservation index。

例 2：round 5 的 SHA-256 → BLAKE2b-256 是状态替换，Contract 只显示当轮 `verify.checksum_behavior`、`manifest.generation` 等新版本，并在 `CURRENT SUPERSESSIONS` 指明替换旧行为。

效果：15 轮 Contract 降至 369,358 B，比 full v2 少 93.27%。但纯 transition 在 round 6 暴露出执行断链：Agent 构建了 `/tmp/dpipe-transition-check`，没有刷新 verifier 使用的 `/app/dpipe`，该轮只有 679/716。

### 2.6 优化五：transition-anchor——补回稳定执行约束

transition-anchor 将“不属于本轮业务变化、但每轮交付都必须满足”的要求从 preserved 状态提升为 execution anchor。它不扩大业务需求，只保证 Coding Agent 的修改最终落到评价系统实际使用的产物。

例 1：`build.go_command` 每轮明确给出工作目录 `/app/`、命令 `go build -o dpipe ./...` 和产物 `dpipe`。round 6 加入仅 519 B 的锚点内容后，Agent 更新了正确二进制，同轮从 679/716 提升至 711/716。

例 2：构建要求没有被 audit/impute 业务 spec 引用，因此不是 dependency；它仍必须出现，因为缺失它会让“代码修改 → 构建产物 → verifier”链路断开。这正是 anchor 与普通 dependency 的区别。

效果：相对 full v2，Contract 减少 93.14%、成本减少 61.41%，并恢复到 99.77% 与 10/15 轮全过。

### 2.7 优化六：general-anchor——从任务特例推广为命名空间规则

早期 anchor 可以被实现成任务特定白名单；general-anchor 改为从 active requirements 中选择 semantic key 以 `build.*` 或 `execution.*` 开头的项目。这样新任务只要使用稳定命名空间，就能自动获得构建和执行锚点。

例 1：本任务的 `build.go_command` 匹配 `build.*`，因此自动进入 execution anchor 区。

例 2：未来若 IR 包含 `execution.test_command` 或 `execution.output_path`，同一规则会自动选择它们，无须再把具体 ID 写入代码。

本任务中泛化前后的生成 Contract 逐文件相同，因此 general-anchor 的贡献是可迁移性，不是本次任务上的输入变化；其 Sol reward 0.6667 与 transition-anchor 的相同 reward 也不能视为新的精度提升。

### 2.8 每轮计算链

每轮实际经过以下状态转换：

| 步骤 | 输入 | 输出 | 主要校验 |
|---:|---|---|---|
| 1. 原文切分 | 当前轮自然语言 instruction | 带 offset、原文、SHA-256 的 clause ledger | 所有 clause 拼接后必须逐字还原原 instruction |
| 2. 语义编译 | 上轮累计 Intent IR + 当前 clause ledger + 当前原文 | `intent_delta.json` | normative clause 必须映射到 requirement；修改只能指向 active 且同 semantic key 的 requirement |
| 3. 状态归并 | 上轮 IR + 当前 delta | 当前轮 `intent_ir.json` | active key 唯一；supersession 链、来源轮次和 hash 一致 |
| 4. 执行切片 | 当前 IR + 当前 delta | `intent_view.json` | 确定 touched、dependency、execution anchor、preserved 和 current supersession 集合 |
| 5. Contract 渲染 | 当前 IR + view | 当前轮 `intent_contract.md`，也是 Agent 的 `instruction.md` | contract-only 副本必须与编译产物字节一致 |
| 6. Coding Agent | Contract + 上轮持久化代码 | 代码、测试、构建产物、Agent trajectory | Agent 自测及指定的精确构建命令 |
| 7. 评价 | 当前工作区 + 累积 verifier | `CASE_RESULT`、轮次 reward | 全部 case 通过时该轮 reward=1 |

这里的“优化”发生在两个层面：步骤 1–5 减少重复信息并提高规格精度；步骤 6 通过执行锚点把“理解正确”连接到“正确产出可被 verifier 使用的二进制”。

## 3. Sol 实验结果

### 3.1 有效优化运行总表

| Sol 版本 | Harbor reward | 全量通过轮次 | 累计通过/总数 | 累计通过率 | 输入 tokens | 输出 tokens | 成本 |
|---|---:|---:|---:|---:|---:|---:|---:|
| v2 full fixed | 0.6667 | 10/15 | 11,009/11,034 | 99.77% | 28,567,394 | 122,799 | $22.379521 |
| v2 compact rerun | 0.6667 | 10/15 | 11,009/11,034 | 99.77% | 17,604,185 | 130,674 | $13.878706 |
| v2 focused | 0.6667 | 10/15 | 11,009/11,034 | 99.77% | 9,215,879 | 131,015 | $8.804213 |
| v2 transition | 0.6000 | 9/15 | 10,961/11,034 | 99.34% | 9,791,634 | 134,101 | $9.158943 |
| v2 transition-anchor | 0.6667 | 10/15 | 11,009/11,034 | 99.77% | 9,442,951 | 129,783 | $8.636315 |
| v2 general-anchor | 0.6667 | 10/15 | 11,009/11,034 | 99.77% | 8,668,433 | 133,580 | $8.428238 |

### 3.2 v2 general-anchor 完整 15 轮结果

下表逐轮列出 verifier、二元 reward 和 `trajectory.json.final_metrics` 的全部汇总字段。Reasoning tokens 是 completion tokens 的子集，不应重复加到总 token 中。

| 轮次 | 通过/总数 | 通过率 | Reward | Prompt | Cache | Completion | Reasoning | Agent 步数 | 成本(USD) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 219/219 | 100.00% | 1 | 1,091,163 | 1,046,528 | 22,598 | 7,091 | 34 | 1.049111 |
| 2 | 481/481 | 100.00% | 1 | 975,005 | 931,840 | 17,247 | 4,288 | 28 | 0.910099 |
| 3 | 535/535 | 100.00% | 1 | 752,564 | 702,592 | 11,493 | 3,053 | 22 | 0.710785 |
| 4 | 639/639 | 100.00% | 1 | 797,906 | 753,792 | 12,591 | 3,233 | 26 | 0.729793 |
| 5 | 675/680 | 99.26% | 0 | 827,720 | 758,912 | 8,976 | 2,938 | 29 | 0.758317 |
| 6 | 711/716 | 99.30% | 0 | 516,595 | 477,056 | 10,928 | 2,853 | 20 | 0.567538 |
| 7 | 734/739 | 99.32% | 0 | 368,314 | 321,024 | 4,763 | 1,349 | 17 | 0.412830 |
| 8 | 764/769 | 99.35% | 0 | 391,037 | 359,040 | 5,880 | 1,147 | 18 | 0.389204 |
| 9 | 811/816 | 99.39% | 0 | 590,743 | 537,984 | 7,123 | 1,212 | 20 | 0.568690 |
| 10 | 851/851 | 100.00% | 1 | 354,942 | 320,768 | 5,299 | 864 | 18 | 0.370983 |
| 11 | 876/876 | 100.00% | 1 | 647,319 | 598,784 | 9,413 | 3,672 | 23 | 0.621914 |
| 12 | 893/893 | 100.00% | 1 | 258,315 | 229,120 | 3,931 | 989 | 16 | 0.287048 |
| 13 | 916/916 | 100.00% | 1 | 347,957 | 313,472 | 5,392 | 873 | 16 | 0.371169 |
| 14 | 944/944 | 100.00% | 1 | 530,495 | 494,336 | 4,985 | 615 | 20 | 0.442070 |
| 15 | 960/960 | 100.00% | 1 | 218,358 | 192,768 | 2,961 | 401 | 14 | 0.238687 |
| **合计** | **11,009/11,034** | **99.77%** | **10/15** | **8,668,433** | **8,038,016** | **133,580** | **34,578** | **321** | **8.428238** |

round 5–9 的每轮 5 个失败均来自相同的 manifest schema；round 10 的 manifest 格式需求使实现随后修复，因此 round 10–15 恢复全量通过。这里的 10/15 即 Harbor mean reward 0.6667。

### 3.3 压缩收益

以 v2 full fixed 为参照：

| 版本 | Contract 字节变化 | 输入 token 变化 | 成本变化 | 正确性变化 |
|---|---:|---:|---:|---|
| compact | -52.79% | -38.38% | -37.98% | 不变：99.77%，10/15 轮全过 |
| focused | -87.46% | -67.74% | -60.66% | 不变：99.77%，10/15 轮全过 |
| transition-anchor | -93.14% | -66.95% | -61.41% | 不变：99.77%，10/15 轮全过 |
| general-anchor | -93.14% | -69.66% | -62.34% | 不变：99.77%，10/15 轮全过 |

compact 证明删除重复证据原文不会损失本任务精度；focused 证明大多数未变化需求只保留索引即可；transition 进一步证明持久化实现和回归测试可以承载前态。但 transition 若没有执行锚点，会出现 Agent 自测通过、verifier 却使用旧二进制的断链。

### 3.4 逐轮正确性特征

除 transition 外，full、compact、focused、transition-anchor、general-anchor 的逐轮 case 结果完全一致：round 1–4 和 round 10–15 全过，round 5–9 每轮固定少 5 个 manifest case，累计少 25 个 case。这说明这些 profile 在语义上基本等价，压缩没有造成额外的随机遗忘。

transition 的 round 6 只有 679/716，主要原因不是 audit 与 impute 的源代码未实现，而是 Agent 将检查二进制构建到 `/tmp/dpipe-transition-check`，没有刷新 verifier 使用的 `/app/dpipe`。增加 `build.go_command` 锚点后，同轮提升为 711/716；余下 5 个仍是 manifest schema 问题。


### 3.5 未纳入主比较的运行

| 运行 | 状态 | 处理方式 |
|---|---|---|
| v1 contract-only | 完成，reward 0，累计实现明显不足 | 作为早期结构基线，不与 v2 profile 的等语义压缩直接比较 |
| v2 初次运行 | 完成但 round 2 后大面积退化，reward 0.0667 | 后续以 `v2-15-fixed` 作为有效 full v2 基线 |
| compact 初次运行 | 只到 round 6，随后 CancelledError | 排除；使用 compact rerun |

## 4. Luna 实验结果

Luna 使用 `v2-general-anchor`，该 Contract 与 Sol general-anchor 逐文件相同。共有两次有效 trial 和一次 Agent 启动超时。

### 4.1 汇总

| Luna 运行 | Harbor reward | 全量通过轮次 | 累计通过/总数 | 累计通过率 | round-15 | 输入 tokens | 输出 tokens | 成本 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2026-09-08 14:42 | 0.0000 | 0/15 | 10,546/11,034 | 95.58% | 927/960 | 9,866,240 | 97,076 | $0.439753 |
| 2026-09-08 15:54 | 0.0000 | 0/15 | 10,414/11,034 | 94.38% | 917/960 | 10,118,508 | 115,303 | $0.467058 |
| **两次有效运行平均** | **0.0000** | **0/15** | **10,480/11,034** | **94.98%** | **922/960** | **9,992,374** | **106,190** | **$0.453406** |
| 2026-09-08 15:45 | — | — | — | — | — | — | — | — |

15:45 的运行报 `AgentSetupTimeoutError`，没有 token、代码或 verifier 结果，不应计为模型失败或纳入均值。

### 4.2 逐轮结果

| 轮次 | Luna 14:42 | 通过率 | Luna 15:54 | 通过率 |
|---:|---:|---:|---:|---:|
| 1 | 215/219 | 98.17% | 204/219 | 93.15% |
| 2 | 463/481 | 96.26% | 460/481 | 95.63% |
| 3 | 500/535 | 93.46% | 492/535 | 91.96% |
| 4 | 604/639 | 94.52% | 596/639 | 93.27% |
| 5 | 640/680 | 94.12% | 632/680 | 92.94% |
| 6 | 678/716 | 94.69% | 668/716 | 93.30% |
| 7 | 701/739 | 94.86% | 691/739 | 93.50% |
| 8 | 731/769 | 95.06% | 721/769 | 93.76% |
| 9 | 778/816 | 95.34% | 768/816 | 94.12% |
| 10 | 818/851 | 96.12% | 808/851 | 94.95% |
| 11 | 840/876 | 95.89% | 833/876 | 95.09% |
| 12 | 857/893 | 95.97% | 850/893 | 95.18% |
| 13 | 883/916 | 96.40% | 873/916 | 95.31% |
| 14 | 911/944 | 96.50% | 901/944 | 95.44% |
| 15 | 927/960 | 96.56% | 917/960 | 95.52% |

两次运行从第一轮起都未全量通过，后续主要是在已有实现上继续增量，因此 Harbor reward 始终为 0。最终失败模式也不相同：

- 14:42：`profile` 17、`transform.rollup` 14、`manifest` 1、`transform.detect` 1，共 33 个。
- 15:54：`profile` 32、`transform.fill` 6、`ingest` 3、`compare` 1、`transform.aggregate` 1，共 43 个。

这说明 Luna 的主要瓶颈不是某一个固定 Contract 缺陷，而是首轮基础实现和后续功能覆盖存在较明显的采样波动。执行锚点能保证产物位置正确，却不能替代模型实现复杂需求。

### 4.3 与同输入 Sol 的比较

Sol 与 Luna 均使用 general-anchor，因此下表是同 Contract 对照：

| 模型 | 有效 trial | 平均累计通过率 | 平均 round-15 | Harbor reward | 平均成本 |
|---|---:|---:|---:|---:|---:|
| Sol medium general-anchor | 1 | 99.77% | 960/960 | 0.6667 | $8.428238 |
| Luna medium general-anchor | 2 | 94.98% | 922/960 | 0.0000 | $0.453406 |

Luna 的平均成本约为 Sol 的 5.38%，但累计准确率低 4.79 个百分点，并且没有一轮达到全量通过。由于 Sol 只有一次、Luna 只有两次有效运行，本表是观察性结果，不是统计显著性结论。

## 5. 结论与建议

1. 当前纳入考虑的实验中，首选配置是 **v2 general-anchor**：它保留 99.77% 累计通过率和 0.6667 reward，同时将锚点选择推广为可跨任务复用的规则。
2. full Contract 不适合作为长期执行格式。它保留完整审计价值，但执行时应从同一 IR 派生 focused 或 transition view。
3. 构建和执行锚点必须成为通用机制。仅依赖 Agent 自主选择构建路径，会造成“代码正确、评价产物错误”的假失败。
4. 下一项最有价值的实验是分别对 Sol 与 Luna general-anchor 做 3–5 次独立重复，以估计模型差异和随机波动。

## 6. 有效性限制

- Sol 每个 profile 只有一次有效 trial，无法给出置信区间。
- 优化版本按前序运行结果迭代产生，因此适合工程优化结论，不适合作为完全盲测的无偏估计。
- 各 profile 的模型生成具有随机性。完全相同的 transition-anchor 与 general-anchor Contract 得到不同 token 和成本，说明不能把小幅差异归因于 profile 名称。
- Luna 与 Sol 单价差异很大，成本比较只反映这些记录中的实际账单，不代表固定工作量下的普遍性价比。

# 附录 A：两个有效优化案例的逐步输入与输出

本附录用两个有效实验贯穿同一条计算链，并在每一步为输入和输出各给出两个真实例子：

- 例 1：round 6，`transition → transition-anchor`，优化执行闭环。
- 例 2：round 15，`compact → focused`，优化当前轮注意力与输入长度。

## A.1 原始 instruction → clause

| 类别 | 例1：round 6 | 例2：round 15 |
|---|---|---|
| 输入例 1 | 所有 `dpipe` 命令可接受 `--audit <path>`，成功或失败后追加 audit entry | snapshot 的 `row_hash` 从 MD5 改成相同 row-content 上的 SHA-256 |
| 输出例 1 | `r006-c003`，start=75，end=298，`normative`，映射 `req-r006-001/002` | `r015-c003`，start=97，end=284，`normative`，映射 `req-r015-001` |
| 输入例 2 | impute 的 `column` 与 `method=mean/median/mode` 参数说明 | 新增 tag transform，将常量字符串作为新列写入所有行 |
| 输出例 2 | `r006-c016`，`normative`，映射 `req-r006-007` | `r015-c007`，start=501，end=604，`normative`，映射 `req-r015-002/003` |

对应的 clause disposition 输出：

```json
{"clause_id":"r006-c003","kind":"normative","requirement_ids":["req-r006-001","req-r006-002"]}
{"clause_id":"r015-c007","kind":"normative","requirement_ids":["req-r015-002","req-r015-003"]}
```

这两个例子分别展示了“一段 clause 映射到两个 audit requirement”和“一段 clause 映射到 tag 接口与赋值两个 requirement”。

## A.2 上轮 IR + 当前 clause → Intent Delta

### 输入例 1与输出：round 6 add

输入：round-05 IR 中没有 audit；`r006-c003` 引入全局 audit flag。

输出：

```json
{
  "operation": "add",
  "id": "req-r006-002",
  "target_id": null,
  "semantic_key": "audit.cli_interface_and_trigger",
  "spec": {
    "interface": [
      {"key":"flag","value":"--audit <path>"},
      {"key":"scope","value":"Any dpipe command."}
    ]
  }
}
```

### 输入例 2与输出：round 15 supersede/add

输入：round-14 IR 中 snapshot 仍使用 MD5，且没有 tag；round-15 clauses 要求 SHA-256 和 tag。

输出：

```json
{"operation":"supersede","id":"req-r015-001","target_id":"req-r013-005","semantic_key":"snapshot.row_hash"}
{"operation":"add","id":"req-r015-002","target_id":null,"semantic_key":"transform.tag_interface_and_layout"}
```

两例覆盖 Delta 的新增与替代类别：`add` 不需要 target，`supersede` 必须指向同 semantic key 的 active requirement。

## A.3 上轮 IR + Delta → 当前 Intent IR

| IR 输入/输出类别 | 例1：round 6 | 例2：round 15 |
|---|---|---|
| 输入状态 | round-05 IR：134 active、13 superseded | round-14 IR：215 active、50 superseded |
| Delta | 10 add、1 supersede | 3 add、1 supersede |
| 输出 active 例子 | `req-r006-002 audit.cli_interface_and_trigger` | `req-r015-002 transform.tag_interface_and_layout` |
| 输出 superseded 例子 | 旧 `req-r001-042 pipeline.execution` | 旧 `req-r013-005 snapshot.row_hash` |
| 输出新状态 | round-06 IR：144 active、14 superseded | round-15 IR：218 active、51 superseded |

替代输出的两个实例：

```json
{"semantic_key":"pipeline.execution","status":"superseded","superseded_round":6}
{"semantic_key":"snapshot.row_hash","id":"req-r015-001","status":"active","supersedes":"req-r013-005"}
```

## A.4 当前 IR + Delta → Intent View

### 例 1：transition-anchor view

输入：round-06 IR、round-06 Delta，以及 anchor 选择规则。

输出：

```json
{
  "touched_count": 11,
  "dependency_requirement_ids": ["req-r003-004", "req-r005-002"],
  "execution_anchor_requirement_ids": ["req-r001-048"],
  "preserved_count": 130,
  "current_superseded_requirement_ids": ["req-r001-042"]
}
```

### 例 2：focused view

输入：与 compact 完全相同的 round-15 IR 和 Delta。两组文件逐字节相同，变化只发生在确定性 view/render 阶段。

输出：

```json
{
  "touched_count": 7,
  "dependency_count": 0,
  "preserved_count": 211,
  "superseded_count": 51
}
```

例 1额外选择 execution anchor；例 2将未变化需求划入 preservation index。

## A.5 IR + View → Intent Contract

### 输出例 1：transition-anchor

输入：round-06 IR 中的 `req-r001-048` 与 transition view。

输出类别一——执行锚点：

```text
[EXECUTION ANCHORS]
working_directory = /app/
build_command      = go build -o dpipe ./...
output_binary      = dpipe
```

输出类别二——前态保存：

```text
Preserved active requirements: 130
Preserved-state SHA-256: b03e84ab5fc98c0b76f7bfb768fcee651b50af2419c5bd94b7ab8fe9251dcfcc
```

### 输出例 2：compact 与 focused

输入：相同的 round-15 IR/Delta。

```text
compact 输出：完整展开全部 218 个 active requirements，并保留51条 tombstone
focused 输出：完整展开7个 touched、0个 dependency；211个 active 仅进入 preservation index
```

对应输入长度：

| round-15 Contract | 字节数 | 相对 compact |
|---|---:|---:|
| compact | 260,272 B | 基线 |
| focused | 45,873 B | -82.37% |

## A.6 Contract + 持久化代码 → Coding Agent 输出

### 例 1：transition 与 transition-anchor

| Agent 输入 | 输出例 1 | 输出例 2 |
|---|---|---|
| 无锚点 transition Contract | 构建到 `/tmp/dpipe-transition-check` | `go test ./...` 通过，但 `/app/dpipe` 未刷新 |
| transition-anchor Contract | 执行 `go build -o dpipe ./...` | 使用 `./dpipe` 完成 audit 成功/失败 smoke test |

### 例 2：compact 与 focused

两者都输出了 snapshot SHA-256 与 tag 实现，并最终完成：

```text
实现例 1：snapshot.go 使用 sha256.Sum256(strings.Join(rowStrings, "\n"))
实现例 2：main.go 增加 tag dispatch 和 literal assignment
验证输出：go test、go vet、go build 均通过
```

资源输出对比：

| round-15 Agent 输出 | compact | focused |
|---|---:|---:|
| Prompt tokens | 959,811 | 391,581 |
| Completion tokens | 3,027 | 3,610 |
| Agent 步数 | 16 | 18 |
| 成本 | $0.762197 | $0.333078 |

focused 的 prompt tokens 减少59.20%、成本减少56.30%；输出 token 略增，说明节省来自更短的输入，而不是少实现功能。

## A.7 代码与构建产物 → Verifier 输出

### Verifier 输出例 1：execution anchor

```text
c681 audit basic：无锚点 status=fail，actual="expected=0 actual=1"
c681 audit basic：有锚点 status=success，actual="matched expectation"

c702 impute mean：无锚点 status=fail，actual="expected=20 actual="
c702 impute mean：有锚点 status=success，actual="matched expectation"
```

轮次汇总：679/716 → 711/716。

### Verifier 输出例 2：focused

```text
compact round 15：960/960，reward=1
focused round 15：960/960，reward=1
```

两个具体 case 类别也均通过：snapshot `row_hash` 为64位 SHA-256；tag 的 value 保持 literal 且缺少 `as` 时返回精确错误。focused 在显著缩短输入的同时保持了与 compact 相同的 verifier 输出。

## A.8 两个有效案例的端到端关系

| 阶段 | 例1：transition-anchor | 例2：compact→focused |
|---|---|---|
| 上一版本问题 | 构建要求被折叠进 prior state | 每轮完整展开所有 active spec |
| 优化输入 | transition View + active `build.go_command` | 与 compact 相同的 IR 与 Delta |
| 优化输出 | 增加 execution-anchor 区 | touched/dependency 详述 + preservation index |
| Contract 变化 | round 6 增加519 B | round 15 减少214,399 B |
| Agent 变化 | 构建标准位置的 `dpipe` | prompt tokens 减少59.20% |
| Verifier | 679/716 → 711/716 | 960/960 → 960/960 |

这两个案例分别说明：第一类优化保证执行正确性；第二类优化在不改变 IR 语义和最终正确性的前提下减少上下文。

## 附录 C：原始材料索引

- 早期 Sol A/B 报告：`experiment/compiler/GPT_5_6_SOL_15_ROUND_REPORT.md`
- Intent IR v2 设计：`experiment/compiler/INTENT_IR_V2.md`
- profile 渲染实现：`experiment/compiler/render_active_ir.py`
- general-anchor 编译产物：`experiment/compiled/simple-v2-general-anchor/`
- Sol general-anchor 运行：`experiment/runs/gpt-5.6-sol-medium-contract-only-v2-general-anchor-15/2026-09-08__11-31-27/`
- Luna 有效运行 A：`experiment/runs/gpt-5.6-luna-medium-contract-only-v2-general-anchor-15/2026-09-08__14-42-06/`
- Luna 启动超时：`experiment/runs/gpt-5.6-luna-medium-contract-only-v2-general-anchor-15/2026-09-08__15-45-07/`
- Luna 有效运行 B：`experiment/runs/gpt-5.6-luna-medium-contract-only-v2-general-anchor-15/2026-09-08__15-54-41/`
