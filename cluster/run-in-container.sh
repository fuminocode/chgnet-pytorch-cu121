#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
lis_assert_paths
gpu=()
forward=()
if [[ "${1:-}" == --gpu ]]; then
    : "${SLURM_JOB_ID:?GPU execution requires a Slurm allocation}"
    gpu=(--nv)
    # Preserve Slurm's visibility value through --cleanenv without choosing a card.
    if [[ ${CUDA_VISIBLE_DEVICES+x} ]]; then
        forward+=(--env "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES")
    fi
    shift
fi
for key in SLURM_JOB_ID SLURM_CPUS_PER_TASK SLURM_JOB_PARTITION SLURM_JOB_NODELIST; do
    if [[ ${!key+x} ]]; then
        forward+=(--env "$key=${!key}")
    fi
done
[[ "${1:-}" != -- ]] || shift
[[ $# -gt 0 ]] || { echo 'Usage: bash run-in-container.sh [--gpu] COMMAND [ARGS...]' >&2; exit 2; }
[[ -f "$LIS_IMAGE" && -f "$LIS_IMAGE.sha256" ]] || { echo 'Complete setup-apptainer.sh first' >&2; exit 2; }
[[ -d "$LIS_PROJECT/CGCNN" && -d "$LIS_BASE/container-home" && -d "$TMPDIR" ]] || exit 2
# Verify the image on each process launch; never silently substitute another SIF.
sha256sum --check --status "$LIS_IMAGE.sha256"
lis_load_apptainer
# --cleanenv removes inherited Conda/GNU/Python settings inside the container.
# The explicit private home and --contain prevent use of shared home and /tmp.
# No compiler/CUDA module or physical GPU index is selected here.
# Bash 4.2 + nounset treats empty arrays as unset; guarded expansions omit them
# without adding a spurious empty argument. Keep the nested quotes for GPU lists.
exec env -u APPTAINERENV_LD_LIBRARY_PATH -u SINGULARITYENV_LD_LIBRARY_PATH \
    apptainer exec --cleanenv --contain --no-mount hostfs \
    --home "$LIS_BASE/container-home" --bind "$LIS_BASE:$LIS_BASE" \
    --pwd "$LIS_PROJECT/CGCNN" ${gpu[@]+"${gpu[@]}"} ${forward[@]+"${forward[@]}"} "$LIS_IMAGE" \
    /bin/bash --noprofile --norc -c 'source "$1"; shift; exec "$@"' \
    wzz-container "$LIS_SCRIPTS/env.sh" "$@"
