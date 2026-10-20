ARG BASE_IMAGE=docker.io/library/python@sha256:4b4c524dc3dce996864e030c7bd9c6b0e517597189fee48f48e05b499442444b
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="LiSuperionic CHGNet runtime dependencies"
LABEL org.opencontainers.image.description="Runtime only: research code and datasets are mounted separately."

ENV UV_PROJECT_ENVIRONMENT=/opt/lisuperionic/venv \
    UV_CACHE_DIR=/var/cache/uv \
    UV_LINK_MODE=hardlink \
    UV_NO_SYSTEM_CONFIG=true \
    UV_PYTHON_DOWNLOADS=never \
    UV_CONCURRENT_BUILDS=1 \
    UV_CONCURRENT_DOWNLOADS=2 \
    UV_CONCURRENT_INSTALLS=2 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install only the environment manager globally; research dependencies go in /opt.
RUN python -m pip install --no-cache-dir uv==0.12.16

# Explicit COPY allowlist: no application sources, CIF, labels or credentials.
COPY pyproject.toml uv.lock /opt/lisuperionic/project/
COPY SOURCE_MANIFEST.json install_runtime.sh verify_runtime.py /opt/lisuperionic/

# Avoid keeping a second full copy of CUDA wheels in this large runtime image.
# The workflow caches completed image layers with BuildKit/GitHub Actions.
RUN bash /opt/lisuperionic/install_runtime.sh

ENV PATH="/opt/lisuperionic/venv/bin:${PATH}"
WORKDIR /work
CMD ["/opt/lisuperionic/venv/bin/python", "/opt/lisuperionic/verify_runtime.py"]
