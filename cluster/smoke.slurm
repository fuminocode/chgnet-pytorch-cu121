#!/usr/bin/env bash
#SBATCH --job-name=wzz-chgnet-ci-smoke
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=/public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/logs/smoke-%j.out
#SBATCH --error=/public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/logs/smoke-%j.err
set -euo pipefail
source /public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/env.sh
: "${SLURM_JOB_ID:?Use sbatch}"
lis_assert_paths
run_id="chgnet-runtime-ci-smoke-20261020-${SLURM_JOB_ID}"
run_dir="$LIS_PROJECT/experiments/runs/$run_id"
mkdir "$run_dir"
trap 'rc=$?; trap - EXIT; printf "%s\n" "$rc" > "$run_dir/exit_code.txt"; exit "$rc"' EXIT
cp -- "$0" "$run_dir/submitted-script.slurm"
cp -- "$LIS_SCRIPTS/env.sh" "$LIS_SCRIPTS/run-in-container.sh" "$run_dir/"
scontrol show job -dd "$SLURM_JOB_ID" > "$run_dir/slurm-job.txt"
runner="$LIS_SCRIPTS/run-in-container.sh"
srun bash "$runner" --gpu "$LIS_PYTHON" -X utf8 -m lisuperionic_structure.server_preflight \
    --output "$run_dir/preflight.json"
srun bash "$runner" --gpu "$LIS_PYTHON" -X utf8 -m lisuperionic_structure.check_chgnet_occupancy \
    --prepared "$LIS_PROJECT/experiments/runs/20261013-structure-preparation-002" \
    --output "$run_dir/adapter-check" --device cuda --max-sites 128
echo "SMOKE PASSED: $run_dir"
