#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo 'Run bash setup-runtime.sh; do not source it.' >&2; return 2
fi
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
lis_assert_paths
if [[ "${1:-}" == --check-paths && $# == 1 ]]; then
    echo 'PASS personal paths; no writes or downloads.'; exit 0
fi
[[ $# -le 1 ]] || { echo 'Usage: bash setup-runtime.sh docker://REGISTRY/IMAGE@sha256:DIGEST' >&2; exit 2; }
source_uri="${1:-}"
if [[ -z "$source_uri" && -f "$LIS_IMAGE.source.txt" ]]; then
    IFS= read -r source_uri < "$LIS_IMAGE.source.txt"
fi
[[ "$source_uri" =~ ^docker://[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]] || {
    echo 'Supply the immutable image reference from the successful GitHub Actions summary.' >&2; exit 2;
}
[[ -d "$LIS_PROJECT/CGCNN" && -f "$LIS_ARCHIVE" ]] || {
    echo 'The original project/data archive must already be present.' >&2; exit 2;
}
for name in run-in-container.sh wzz_shell.sh smoke.slurm train.slurm; do
    [[ -r "$LIS_SCRIPTS/$name" ]] || { echo "Upload missing file: $name" >&2; exit 2; }
done
mkdir -p "$LIS_BASE/images" "$LIS_BASE/container-home" "$LIS_SCRIPTS/logs" \
    "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$APPTAINER_CONFIGDIR" \
    "$UV_CACHE_DIR" "$UV_CREDENTIALS_DIR" "$TMPDIR" \
    "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$TORCH_HOME" "$MPLCONFIGDIR"
log="$LIS_SCRIPTS/logs/setup-$(date +%Y%m%dT%H%M%S)-$$.log"
exec > >(tee "$log") 2>&1
echo "Setup log: $log"
printf '%s  %s\n' f6c7e6f5079589e72af7182752d98bd185999e9cac36f58fd0d445f82edc4df8 \
    "$LIS_ARCHIVE" | sha256sum --check -
lis_load_apptainer
apptainer --version
if [[ -f "$LIS_IMAGE.source.txt" ]]; then
    [[ "$(cat "$LIS_IMAGE.source.txt")" == "$source_uri" ]] || {
        echo 'Existing image belongs to a different source; preserve it and use a new image path for a new build.' >&2; exit 2;
    }
fi
if [[ ! -e "$LIS_IMAGE" ]]; then
    [[ ! -e "$LIS_IMAGE.sha256" ]] || { echo 'Image missing but checksum exists; inspect before retry.' >&2; exit 2; }
    apptainer pull "$LIS_IMAGE" "$source_uri"
fi
apptainer inspect --json "$LIS_IMAGE" > "$log.image-inspect.json"
if [[ -f "$LIS_IMAGE.sha256" ]]; then
    sha256sum --check "$LIS_IMAGE.sha256"
else
    sha256sum "$LIS_IMAGE" > "$LIS_IMAGE.sha256"
fi
if [[ ! -f "$LIS_IMAGE.source.txt" ]]; then
    printf '%s\n' "$source_uri" > "$LIS_IMAGE.source.txt"
fi
runner="$LIS_SCRIPTS/run-in-container.sh"
# The completed image already contains all Python/CUDA dependencies.
# There is deliberately no pip install, uv sync, or package download on the cluster.
bash "$runner" "$LIS_PYTHON" /opt/lisuperionic/verify_runtime.py
bash "$runner" "$LIS_PYTHON" - "$LIS_PROJECT" <<'PY'
import hashlib, json, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
manifest = json.loads((root / 'BUNDLE_MANIFEST.json').read_text())
for relative, expected in manifest['files'].items():
    path = root / relative
    if path.is_symlink() or not path.resolve().is_relative_to(root):
        raise ValueError('Unexpected bundle path: ' + relative)
    assert path.stat().st_size == expected['bytes'], relative
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected['sha256'], relative
print('PASS original bundle fingerprints:', len(manifest['files']))
PY
personal_rc="$LIS_BASE/wzz_bashrc"
[[ ! -L "$personal_rc" && ( ! -e "$personal_rc" || -f "$personal_rc" ) ]] || exit 2
hook="source $LIS_SCRIPTS/wzz_shell.sh"
if [[ ! -f "$personal_rc" ]] || ! grep -Fqx -- "$hook" "$personal_rc"; then
    if [[ -f "$personal_rc" ]]; then
        cp -p -- "$personal_rc" "$personal_rc.bak.$(date +%Y%m%dT%H%M%S).$$"
    fi
    printf '\n# wzz: complete runtime image, 2026-10-20\n%s\n' "$hook" >> "$personal_rc"
fi
echo "SETUP PASSED: source $personal_rc; run smoke.slurm before train.slurm."
echo 'No Python dependencies were installed, and no GPU calculation ran during setup.'
