import importlib
import importlib.machinery
import os

from cffi import FFI

ffi = FFI()
assert ffi.new("int *", 42)[0] == 42
assert ffi.sizeof("void *") == 8
print("CFFI allocation PASS", flush=True)

# NIST SP 800-38A, F.1.1 AES-128 ECB, first block.
key = bytes.fromhex("2b7e151628aed2a6abf7158809cf4f3c")
plaintext = bytes.fromhex("6bc1bee22e409f96e93d7e117393172a")
ciphertext = bytes.fromhex("3ad77bb40d7a3660a89ecaf32466ef97")
for namespace in ("Crypto", "Cryptodome"):
    aes = importlib.import_module(f"{namespace}.Cipher.AES")
    assert aes.new(key, aes.MODE_ECB).encrypt(plaintext) == ciphertext

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

encryptor = Cipher(algorithms.AES(key), modes.ECB(), backend=default_backend()).encryptor()
assert encryptor.update(plaintext) + encryptor.finalize() == ciphertext
encryptor = Cipher(algorithms.AES(key), modes.ECB(), backend=default_backend()).encryptor()
encryptor.update(b"x" * 15)
try:
    encryptor.finalize()
except ValueError:
    pass
else:
    raise AssertionError("Incomplete AES block was accepted")
try:
    Cipher(algorithms.AES(key * 2), modes.XTS(bytes(16)), backend=default_backend()).encryptor()
except ValueError:
    pass
else:
    raise AssertionError("Duplicate XTS key halves were accepted")
print("Crypto, Cryptodome and cryptography AES PASS", flush=True)

import regex
from lxml import _elementpath, builder, etree, objectify, sax
from lxml.html import _difflib, diff

for module in (_elementpath, builder, etree, objectify, sax, _difflib, diff):
    assert isinstance(module.__loader__, importlib.machinery.ExtensionFileLoader), module.__name__

transform = etree.XSLT(etree.XML(b'<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:template match="/"><result><xsl:value-of select="/value"/></result></xsl:template></xsl:stylesheet>'))
assert transform(etree.XML(b"<value>42</value>")).getroot().text == "42"
assert objectify.fromstring(b"<value>42</value>").pyval == 42
assert builder.E("value", "42").text == "42"
assert list(_elementpath.iterfind(etree.XML(b"<root><value>42</value></root>"), "value"))[0].text == "42"
assert callable(sax.saxify) and callable(_difflib.SequenceMatcher)
assert "<ins>new</ins>" in diff.htmldiff("old", "new")
assert regex.findall("aba", "ababa", overlapped=True) == ["aba", "aba"]
print("lxml XSLT and regex overlap PASS", flush=True)

from curl_cffi import requests

response = requests.get(os.environ["MINI_TEST_URL"], timeout=10)
assert response.status_code == 200
assert response.content == b"mini-package-http\n"
print("curl_cffi HTTP PASS", flush=True)
