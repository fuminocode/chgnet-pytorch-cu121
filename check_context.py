"""Read-only CI input checks; no model code, dataset access or GPU use."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'SOURCE_MANIFEST.json').read_text())
assert manifest['target_platform'] == 'linux/amd64'
for name, expected in manifest['dependencies_sha256'].items():
    assert name in {'pyproject.toml', 'uv.lock'}, name
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
expected_context = {'Dockerfile', 'pyproject.toml', 'uv.lock', 'SOURCE_MANIFEST.json',
                    'install_runtime.sh', 'verify_runtime.py'}
lines = (root / '.dockerignore').read_text().splitlines()
assert lines[0] == '**'
assert {line[1:] for line in lines if line.startswith('!')} == expected_context
for name in expected_context:
    assert (root / name).is_file() and not (root / name).is_symlink(), name
print('PASS original dependency fingerprints and explicit runtime-only Docker context.')
print('This does not prove a Docker image has been built or GPU execution works.')
