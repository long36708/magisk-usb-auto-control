"""Build the flashable Magisk module zip from the module/ directory."""

import os
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'module')
OUT = os.path.join(ROOT, 'magisk-usb-auto-control.zip')

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for base, _dirs, files in os.walk(SRC):
        for name in files:
            path = os.path.join(base, name)
            rel = os.path.relpath(path, SRC).replace('\\', '/')
            info = zipfile.ZipInfo(rel)
            info.create_system = 3  # Unix: honor permission bits on Android
            info.external_attr = (0o100755 if name.endswith('.sh') or name == 'update-binary' else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(path, 'rb') as fh:
                z.writestr(info, fh.read())
            print(f'{rel}  {oct(info.external_attr >> 16 & 0o777)}')

print(f'\nBuilt: {OUT} ({os.path.getsize(OUT)} bytes)')
