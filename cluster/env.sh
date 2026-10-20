# Source only in the personal session or container. Shared HOME and rc stay intact.
export LIS_BASE=/public/home/xiaohe2/zizhangw
export LIS_SCRIPTS="$LIS_BASE/chgnet-runtime-ci-20261020"
export LIS_PROJECT="$LIS_BASE/projects/chgnet-server-20261013-002"
export LIS_ARCHIVE="$LIS_BASE/incoming/chgnet-server-20261013-002.tar.gz"
export LIS_UV=/usr/local/bin/uv
export LIS_ENV=/opt/lisuperionic/venv
export LIS_PYTHON="$LIS_ENV/bin/python"
export LIS_IMAGE="$LIS_BASE/images/chgnet-runtime-ci-20261020.sif"
# Image source is supplied once to setup-runtime.sh after the CI build.
export LIS_APPTAINER_MODULE=apps/apptainer/1.5.4
export APPTAINER_CACHEDIR="$LIS_BASE/cache/apptainer"
export APPTAINER_TMPDIR="$LIS_BASE/tmp/apptainer"
export APPTAINER_CONFIGDIR="$LIS_BASE/config/apptainer"
export XDG_CACHE_HOME="$LIS_BASE/cache/container-xdg"
export XDG_CONFIG_HOME="$LIS_BASE/config/container-xdg"
export XDG_DATA_HOME="$LIS_BASE/data/container-xdg"
# Runtime caches remain personal; all installed dependencies are already in SIF.
export UV_CACHE_DIR="$LIS_BASE/cache/uv-apptainer"
export UV_CREDENTIALS_DIR="$LIS_BASE/data/uv-apptainer/credentials"
export UV_PROJECT_ENVIRONMENT="$LIS_ENV"
export UV_NO_SYSTEM_CONFIG=true
export UV_NO_CONFIG=false
unset UV_CONFIG_FILE
export UV_CONCURRENT_BUILDS=1 UV_CONCURRENT_DOWNLOADS=4 UV_CONCURRENT_INSTALLS=2
export TMPDIR="$LIS_BASE/tmp/container"
export TORCH_HOME="$LIS_BASE/cache/torch-apptainer"
export MPLCONFIGDIR="$LIS_BASE/cache/matplotlib-apptainer"
export PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUTF8=1 PYTHONUNBUFFERED=1
export PYTHONPATH="$LIS_PROJECT/CGCNN"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export MKL_NUM_THREADS="$OMP_NUM_THREADS" OPENBLAS_NUM_THREADS="$OMP_NUM_THREADS"
export CUBLAS_WORKSPACE_CONFIG=:4096:8

lis_assert_paths() {
    [[ -d "$LIS_BASE" && ! -L "$LIS_BASE" ]] || {
        echo "Personal base must exist and not itself be a symlink: $LIS_BASE" >&2; return 2;
    }
    # /opt venv and /usr/local/bin/uv exist inside the read-only image only.
    [[ "$LIS_ENV" == /opt/lisuperionic/venv && "$LIS_UV" == /usr/local/bin/uv ]] || return 2
    local root resolved path
    root=$(realpath -- "$LIS_BASE") || return $?
    for path in "$LIS_SCRIPTS" "$LIS_SCRIPTS/logs" "$LIS_PROJECT" "$LIS_ARCHIVE" \
        "$LIS_IMAGE" "$LIS_IMAGE.sha256" "$LIS_IMAGE.source.txt" \
        "$LIS_BASE/images" "$LIS_BASE/envs" "$LIS_BASE/cache" "$LIS_BASE/tmp" \
        "$LIS_BASE/config" "$LIS_BASE/data" "$LIS_BASE/container-home" \
        "$LIS_BASE/wzz_bashrc" "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" \
        "$APPTAINER_CONFIGDIR" "$UV_CACHE_DIR" "$UV_CREDENTIALS_DIR" "$TMPDIR" \
        "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$TORCH_HOME" "$MPLCONFIGDIR"; do
        resolved=$(realpath -m -- "$path") || return $?
        [[ "$resolved" == "$root/"* ]] || {
            echo "Managed path escapes personal base: $path -> $resolved" >&2; return 2;
        }
    done
}

lis_load_apptainer() {
    type module >/dev/null 2>&1 || {
        echo 'module is not initialized. Use the cluster login shell with Modules enabled.' >&2; return 2;
    }
    module load "$LIS_APPTAINER_MODULE" || return $?
    command -v apptainer >/dev/null || return $?
}
