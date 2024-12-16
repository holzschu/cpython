# This file must be used with "%run bin/activate.py" from a notebook in Carnets
# you cannot run it directly

import os
import sys

homePath = os.environ['HOME']
libraryPath = os.path.join(homePath, "Library")

# deactivate:
if (os.environ.get('_OLD_VIRTUAL_PATH') is not None):
    os.environ['PYTHONPYCACHEPREFIX'] = os.path.join(libraryPath, "__pycache__")
    os.environ['PYTHONUSERBASE'] = libraryPath
    os.environ['PATH'] = os.environ['_OLD_VIRTUAL_PATH']
    del os.environ['_OLD_VIRTUAL_PATH']
    virtualEnvPath = os.path.join(os.environ['VIRTUAL_ENV'], "lib/python3.9/site-packages")
    sys.path.remove(virtualEnvPath)
    del os.environ['VIRTUAL_ENV']

path = os.environ['PATH']

# Always recompute the path based on the current directory:
virtualEnvDir = os.path.dirname(os.path.realpath(__file__)) # newEnvironment/bin
virtualEnvDir = os.path.dirname(virtualEnvDir) # newEnvironment
os.environ['_OLD_VIRTUAL_PATH'] = path
os.environ['PYTHONPYCACHEPREFIX'] = os.path.join(virtualEnvDir, "__pycache__")
os.environ['PYTHONUSERBASE'] = virtualEnvDir
os.environ['VIRTUAL_ENV'] = virtualEnvDir
os.environ['PATH'] = virtualEnvDir + '/bin:' + path
# Edit sys paths too:
libraryPath = os.path.join(libraryPath, "lib/python3.9/site-packages")
if (libraryPath in sys.path): 
    sys.path.remove(libraryPath)
if (libraryPath.startswith("/private")):
    libraryPath = libraryPath.removeprefix("/private")
    if (libraryPath in sys.path): 
        sys.path.remove(libraryPath)
else:
    libraryPath = os.path.join("/private", libraryPath)
    if (libraryPath in sys.path): 
        sys.path.remove(libraryPath)
sys.path.insert(6, os.path.join(virtualEnvDir, "lib/python3.9/site-packages"))
