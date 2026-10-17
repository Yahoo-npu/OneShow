#!/usr/bin/env python3
"""Create a GitHub-ready source archive without local delivery or account data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import plistlib

root = Path(__file__).resolve().parent.parent
version = plistlib.loads((root / 'Config/Info.plist').read_bytes())['CFBundleShortVersionString']
destination = root / 'dist/release' / f'OneShow-{version}-source.zip'
destination.parent.mkdir(parents=True, exist_ok=True)
entries = ['Sources', 'Resources', 'Config', 'Tests', 'scripts', 'docs', '.github',
           'README.md', '.gitignore', 'CHANGELOG.md', 'CONTRIBUTING.md', 'LICENSE']
with ZipFile(destination, 'w', ZIP_DEFLATED) as archive:
    for name in entries:
        path = root / name
        files = sorted(path.rglob('*')) if path.is_dir() else [path]
        for file in files:
            if file.is_file() and not file.is_symlink() and file.name != '.DS_Store' and '__pycache__' not in file.parts:
                archive.write(file, Path('OneShow') / file.relative_to(root))
print(destination)
