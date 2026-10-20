"""Validate dependency versions/imports without project code, data or GPU use."""
import hashlib
import importlib
from importlib.metadata import version
import json
import platform
from pathlib import Path
import sys

root = Path('/opt/lisuperionic')
source = json.loads((root / 'SOURCE_MANIFEST.json').read_text())
for name, expected in source['dependencies_sha256'].items():
    assert name in {'pyproject.toml', 'uv.lock'}, name
    assert hashlib.sha256((root / 'project' / name).read_bytes()).hexdigest() == expected, name
assert sys.version_info[:3] == (3, 11, 16), sys.version
assert platform.machine() == 'x86_64', platform.machine()
libc, release = platform.libc_ver()
assert libc == 'glibc' and tuple(map(int, release.split('.')[:2])) >= (2, 28), (libc, release)
expected = {
    'torch': '2.5.1+cu121', 'numpy': '1.26.4', 'scipy': '1.14.1',
    'scikit-learn': '1.5.2', 'pymatgen': '2023.11.12', 'chgnet': '0.3.8',
    'ase': '3.23.0', 'cython': '3.0.12', 'pandas': '3.0.6',
    'matplotlib': '3.11.2', 'contourpy': '1.3.3', 'pillow': '12.3.0',
    'spglib': '2.8.0', 'nvidia-ml-py3': '7.352.0',
}
for name, wanted in expected.items():
    actual = version(name)
    assert actual == wanted, (name, actual, wanted)
for module in ['numpy', 'scipy', 'sklearn', 'pymatgen.core', 'chgnet',
               'ase', 'pandas', 'matplotlib', 'contourpy', 'PIL.Image', 'spglib', 'torch']:
    importlib.import_module(module)
import torch
assert torch.version.cuda == '12.1', torch.version.cuda
# Do not call cuda.is_available(), load a model, or make a prediction in CI.
print(json.dumps({
    'status': 'runtime_versions_and_CPU_imports_passed_GPU_NOT_TESTED',
    'python': sys.version, 'libc': (libc, release), 'torch_cuda_build': torch.version.cuda,
    'packages': {name: version(name) for name in expected},
    'research_code_or_data_used': False,
}, indent=2))
