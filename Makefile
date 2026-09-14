.PHONY: test validate-artifacts check

test:
	cd compiler && uv run pytest -q

validate-artifacts:
	cd compiler && uv run python validate_task_copy.py \
		../tasks/pilot-control-3 \
		../tasks/pilot-contract-only-v2-general-anchor-3 \
		--instruction-mode contract-only \
		--compiled-directory ../artifacts/simple-v2-general-anchor

check: test validate-artifacts
	bash -n evaluation/run_single.sh
	python3 -m py_compile evaluation/compute_metrics.py evaluation/validate_dataset.py

