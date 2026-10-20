#!/usr/bin/env bash
#SBATCH --job-name=wzz-chgnet-ci
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=/public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/logs/train-%j.out
#SBATCH --error=/public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/logs/train-%j.err
# One process, 4 CPU cores, 1 GPU. --mem is host RAM, not GPU memory.
set -euo pipefail
source /public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/env.sh
: "${SLURM_JOB_ID:?Use sbatch}"
lis_assert_paths
run_id="chgnet-runtime-ci-20261020-${SLURM_JOB_ID}"
run_dir="$LIS_PROJECT/experiments/runs/$run_id"
launch_dir="$LIS_SCRIPTS/logs/launch-$run_id"
[[ ! -e "$run_dir" ]] || { echo 'Existing run ID; refusing overwrite.' >&2; exit 2; }
mkdir "$launch_dir"
trap 'rc=$?; trap - EXIT; printf "%s\n" "$rc" > "$launch_dir/exit_code.txt"; exit "$rc"' EXIT
cp -- "$0" "$launch_dir/submitted-script.slurm"
cp -- "$LIS_SCRIPTS/env.sh" "$LIS_SCRIPTS/run-in-container.sh" "$LIS_IMAGE.source.txt" "$launch_dir/"
scontrol show job -dd "$SLURM_JOB_ID" > "$launch_dir/slurm-job.txt"
sha256sum "$LIS_IMAGE" "$LIS_ARCHIVE" "$LIS_PROJECT/CGCNN/uv.lock" \
    "$LIS_PROJECT/BUNDLE_MANIFEST.json" > "$launch_dir/input-hashes.txt"
runner="$LIS_SCRIPTS/run-in-container.sh"
bash "$runner" "$LIS_UV" pip freeze --python "$LIS_PYTHON" > "$launch_dir/packages.txt"
bash "$runner" "$LIS_PYTHON" - "$launch_dir/context.json" "$run_id" <<'PY'
import datetime, json, platform, sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({
    'run_id':sys.argv[2], 'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'container_python':sys.version, 'container_libc':platform.libc_ver(),
    'scope':'482 development structures only', 'chunking':False,
    'final_holdout_predicted':False,
    'scheduler_metadata':'See host-side slurm-job.txt; only selected Slurm variables and original GPU visibility are forwarded.',
    'entry':'original verified chgnet_server.py'
}, indent=2) + '\n')
PY
echo "Run ID: $run_id"
echo "Results: $run_dir"
# No uv sync or container pull happens inside the allocated training job.
srun bash "$runner" --gpu "$LIS_PYTHON" -X utf8 "$LIS_PROJECT/chgnet_server.py" --run-id "$run_id"
echo 'Driver finished; inspect status.json and both LR verification files.'
