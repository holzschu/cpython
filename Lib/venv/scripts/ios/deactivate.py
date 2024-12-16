# This file must be used with "%run bin/activate.py" from a notebook in Carnets
# you cannot run it directly

import os
import sys

homePath = os.environ['HOME']
libraryPath = os.path.join(homePath, "Library")

# deactivate:
os.environ['PYTHONPYCACHEPREFIX'] = os.path.join(libraryPath, "__pycache__")
os.environ['PYTHONUSERBASE'] = libraryPath

if (os.environ.get('_OLD_VIRTUAL_PATH') is not None):
    os.environ['PATH'] = os.environ['_OLD_VIRTUAL_PATH']
    del os.environ['_OLD_VIRTUAL_PATH']
    if (os.environ.get('VIRTUAL_ENV') is not None):
        virtualEnvPath = os.path.join(os.environ['VIRTUAL_ENV'], "lib/python3.9/site-packages")
        sys.path.remove(virtualEnvPath)
        libraryPath = os.path.join(libraryPath, "lib/python3.9/site-packages")
        sys.path.insert(6, libraryPath)
        del os.environ['VIRTUAL_ENV']
