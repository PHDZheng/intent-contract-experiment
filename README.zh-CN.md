# Intent Contract 实验

[English](README.md) | [简体中文](README.zh-CN.md)

本仓库是 `dpipe` 15 轮顺序软件演化实验的公开可复现包，包含 Intent IR
编译器、control 与 `v2 general-anchor` 两种任务、准确的编译产物、评测工具，
以及 Sol/Luna 实验报告。

## 仓库内容

- `compiler/`：确定性的 Intent IR/Delta 校验、归并、渲染和任务物化代码，
  以及单元测试。
- `tasks/pilot-control-3/`：原始的 15 轮 Harbor 任务。
- `tasks/pilot-contract-only-v2-general-anchor-3/`：有效的
  `v2 general-anchor` 实验所使用的物化 treatment 任务。
- `artifacts/simple-v2-general-anchor/`：每轮准确的 Delta、累计 IR、执行视图
  和渲染后的 Contract。
- `evaluation/`：Harbor 运行脚本和结果汇总工具。
- `reports/`：Markdown 和 Word 格式的实验报告。
- `locks/`：原实验环境中记录的软件版本与提交版本。

本仓库有意排除了生成的运行结果、模型轨迹、凭据、虚拟环境、缓存和大型数据集
压缩包，也未包含已排除的 `v2 schema-fixed-anchor` 和
`v3 transition-anchor` 实验。

## 环境要求

- Python 3.11 或更高版本
- [`uv`](https://docs.astral.sh/uv/) 或 `pip`
- Docker 和 Harbor，用于端到端 benchmark 执行
- 运行模型实验所需的 Coding Agent 运行环境及其凭据

原实验环境的版本记录位于 `locks/`。历史模型输出具有随机性，并可能受模型
可用性影响；仓库内的 Contract 和测试 fixture 是确定性的输入。

## 验证公开包

使用 `uv`：

```bash
make check
```

也可以使用标准 Python 工具：

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -e './compiler[test]'
python -m pytest -q compiler/tests
python compiler/validate_task_copy.py \
  tasks/pilot-control-3 \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  --instruction-mode contract-only \
  --compiled-directory artifacts/simple-v2-general-anchor
```

任务副本校验器会证明：相较于 control 任务，只有任务名称和各轮 instruction
发生了变化，并且每一轮 treatment instruction 都与仓库内对应的编译 Contract
逐字节一致。

## 运行 benchmark

首先验证 Harbor 任务及其 oracle solution：

```bash
./evaluation/run_single.sh \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  oracle \
  --jobs-dir runs/general-anchor-oracle
```

然后运行 Coding Agent。当对应模型和运行环境可用时，以下配置可用于复现已记录的
Sol 实验：

```bash
AGENT_TYPE=codex \
AGENT_MODEL=openai/gpt-5.6-sol \
AGENT_ATTEMPTS=1 \
HARBOR_N_CONCURRENT=1 \
AGENT_KWARGS='{"reasoning_effort":"medium"}' \
./evaluation/run_single.sh \
  tasks/pilot-contract-only-v2-general-anchor-3 \
  agent \
  --jobs-dir runs/general-anchor-sol
```

请勿提交 `runs/` 目录，其中可能包含模型对话记录、本地路径或模型提供方的元数据。
可以使用以下命令汇总已完成的 Harbor 输出：

```bash
python evaluation/compute_metrics.py \
  --tasks-dir tasks \
  --results-dir runs \
  --model gpt-5.6-sol
```

## 实验结果参考

已记录的 Sol `v2 general-anchor` 实验累计通过 11,009/11,034 个测试用例，
通过率为 99.77%；15 轮中有 10 轮完全通过，Harbor mean reward 为 0.6667。
完整的逐轮结果和两个优化案例见
[`reports/SOL_LUNA_OPTIMIZED_EXPERIMENT_REPORT.md`](reports/SOL_LUNA_OPTIMIZED_EXPERIMENT_REPORT.md)。

## 可复现性与公开说明

任务包包含 verifier 测试和 oracle solution，以便审计已记录的评测结果。由于这些
文件已经公开，本任务可能不再适合作为公开排行榜上的盲测任务；未来进行 held-out
评测时应使用私有测试集。

编译器的语义编译路径可能调用 Codex，因此重新运行语义编译时结果可能发生变化。
校验、IR 归并、从仓库内产物进行渲染以及任务副本验证均为确定性过程。

## 许可证与来源

评测框架和任务格式基于 EvoCodeBench。其 MIT 许可证保存在
`third_party/EvoCodeBench-LICENSE`，来源说明见 `THIRD_PARTY_NOTICES.md`。
除非仓库所有者另行添加许可证，否则其余项目专属材料不授予单独的使用许可。
