"""Minimal '_curses' module, the low-level interface for curses module
which is not meant to be used directly.

Based on ctypes.  It's too incomplete to be really called '_curses', so
to use it, you have to import it and stick it in sys.modules['_curses']
manually.

Note that there is also a built-in module _minimal_curses which will
hide this one if compiled in.
"""

import ctypes
import ctypes.util
import sys


class error(Exception):
    pass


def _find_clib() -> str:
    trylibs = ["ncursesw", "ncurses", "curses"]

    for lib in trylibs:
        path = ctypes.util.find_library(lib)
        if path:
            return path
    raise ModuleNotFoundError("curses library not found", name="_pyrepl._minimal_curses")


_clibpath = _find_clib()
clib = ctypes.cdll.LoadLibrary(_clibpath)

clib.setupterm.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
clib.setupterm.restype = ctypes.c_int

clib.tigetstr.argtypes = [ctypes.c_char_p]
clib.tigetstr.restype = ctypes.c_ssize_t

clib.tparm.argtypes = [ctypes.c_char_p] + 9 * [ctypes.c_int]  # type: ignore[operator]
clib.tparm.restype = ctypes.c_char_p

OK = 0
ERR = -1

# ____________________________________________________________


def setupterm(termstr, fd):
    err = ctypes.c_int(0)
    result = clib.setupterm(termstr, fd, ctypes.byref(err))
    if result == ERR:
        raise error("setupterm() failed (err=%d)" % err.value)


def tigetstr(cap):
    if not isinstance(cap, bytes):
        cap = cap.encode("ascii")
    result = clib.tigetstr(cap)
    if result == ERR:
        return None
    res = ctypes.cast(result, ctypes.c_char_p).value
    # iOS: %p1 to %p8 are for mouse position, which we do not have.
    # Source: https://man7.org/linux/man-pages/man5/user_caps.5.html
    if (sys.platform == 'ios') and (not res is None): 
        res = res.replace(b'%p1', b'').replace(b'%p2', b'').replace(b'%p3', b'').replace(b'%p4', b'').replace(b'%p5', b'').replace(b'%p6', b'').replace(b'%p7', b'').replace(b'%p8', b'')
    return res
    # return ctypes.cast(result, ctypes.c_char_p).value


def tparm(str, i1=0, i2=0, i3=0, i4=0, i5=0, i6=0, i7=0, i8=0, i9=0):
    if (sys.platform == 'ios'): 
        # tparm does not provide the right answer (\x1b[%dD + 4 --> \x1b[0D)
        # so we format the string ourselves.
        # We do not know in advance how many parameters are used in str,
        # so it's done with a "match / case" approach.
        numParameters = str.count(b'%')
        match numParameters:
            case 0:
                return str
            case 1:
                return (str) % (i1)
            case 2:
                return (str) % (i1, i2)
            case 3:
                return (str) % (i1, i2, i3)
            case 4:
                return (str) % (i1, i2, i3, i4)
            case 5:
                return (str) % (i1, i2, i3, i4, i5)
            case 6:
                return (str) % (i1, i2, i3, i4, i5, i6)
            case 7:
                return (str) % (i1, i2, i3, i4, i5, i6, i7)
            case 8:
                return (str) % (i1, i2, i3, i4, i5, i6, i7, i8)
            case _:
                return (str) % (i1, i2, i3, i4, i5, i6, i7, i8, i9)
    # standard case (not iOS):
    result = clib.tparm(str, i1, i2, i3, i4, i5, i6, i7, i8, i9)
    if result is None:
        raise error("tparm() returned NULL")
    return result
