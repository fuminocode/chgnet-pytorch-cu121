#!/usr/bin/env bash
set -euo pipefail
lock_before=$(sha256sum /opt/lisuperionic/project/uv.lock)
uv sync --project /opt/lisuperionic/project --locked --no-cache --no-managed-python \
    --python /usr/local/bin/python --extra cu121 --extra dev --extra chgnet \
    --no-build-package pillow --no-build-package contourpy \
    --no-build-package pandas --no-build-package spglib
[[ "$(sha256sum /opt/lisuperionic/project/uv.lock)" == "$lock_before" ]] || {
    echo 'Original dependency lock changed; aborting build.' >&2; exit 2;
}
/opt/lisuperionic/venv/bin/python /opt/lisuperionic/verify_runtime.py
uv pip freeze --python /opt/lisuperionic/venv/bin/python > /opt/lisuperionic/packages.txt
