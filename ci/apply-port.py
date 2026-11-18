#!/usr/bin/env python3
"""Apply reviewed device changes without deleting existing build outputs."""
import json
from pathlib import Path
import subprocess
import sys

control = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve()
projects = json.loads((control / 'sources.json').read_text())
for project in projects:
    folder = source / project['path']
    if not (folder / '.git').exists():
        folder.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--no-checkout', '--depth=1',
                        '--branch', project['branch'],
                        'https://github.com/' + project['name'] + '.git', str(folder)], check=True)
        subprocess.run(['git', '-C', str(folder), 'checkout', '--detach', project['revision']], check=True)
    current = subprocess.check_output(['git', '-C', str(folder), 'rev-parse', 'HEAD']).decode().strip()
    if current != project['revision']:
        # These are managed device/BSP repositories inside the disposable runner.
        # Leave untracked files and all compilation outputs in place.
        subprocess.run(['git', '-C', str(folder), 'restore', '--source=HEAD', '--', '.'], check=True)
        subprocess.run(['git', '-C', str(folder), 'fetch', '--depth=1',
                        'https://github.com/' + project['name'] + '.git', project['revision']], check=True)
        subprocess.run(['git', '-C', str(folder), 'checkout', '--detach', project['revision']], check=True)
        print('Updated', project['path'], 'to', project['revision'], flush=True)
    patch = control / 'patches' / (folder.name + '.patch')
    # Local patch names follow source folder names, except the common tree.
    if folder.name == 'universal7420-common':
        patch = control / 'patches/universal7420-common.patch'
    if not patch.exists():
        continue
    # Restore only files modified by this project's previous patch version.
    # No clean/reset of the source tree or compilation output is performed.
    tracked = subprocess.check_output(
        ['git', '-C', str(folder), 'diff', '--name-only', '-z'])
    paths = [p.decode() for p in tracked.split(b'\0') if p]
    if paths:
        subprocess.run(['git', '-C', str(folder), 'restore', '--source=HEAD', '--', *paths], check=True)
    subprocess.run(['git', '-C', str(folder), 'apply', '--check', str(patch)], check=True)
    subprocess.run(['git', '-C', str(folder), 'apply', str(patch)], check=True)
    print('Applied', patch.name, 'to', project['path'], flush=True)
