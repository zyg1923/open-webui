# -*- coding: utf-8 -*-
import struct
from pathlib import Path


def imports(path: Path):
    data = path.read_bytes()
    if data[:2] != b"MZ":
        return ["NOT_PE"]
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew : e_lfanew + 4] != b"PE\x00\x00":
        return ["BAD_PE"]
    coff = e_lfanew + 4
    nsec = struct.unpack_from("<H", data, coff + 2)[0]
    opt_size = struct.unpack_from("<H", data, coff + 16)[0]
    opt = coff + 20
    magic = struct.unpack_from("<H", data, opt)[0]
    dd = opt + (112 if magic == 0x20B else 96) + 8  # Import Directory
    rva, _size = struct.unpack_from("<II", data, dd)
    sec = opt + opt_size
    sections = []
    for i in range(nsec):
        o = sec + i * 40
        vs = struct.unpack_from("<I", data, o + 8)[0]
        va = struct.unpack_from("<I", data, o + 12)[0]
        rawsz, ptr = struct.unpack_from("<II", data, o + 16)
        sections.append((va, max(vs, rawsz), ptr))

    def rva_to_off(rva):
        for va, sz, ptr in sections:
            if va <= rva < va + sz:
                return ptr + (rva - va)
        return None

    off = rva_to_off(rva)
    if off is None:
        return ["NO_IMPORT"]
    names = []
    while True:
        ilt, _ts, _fc, name_rva, iat = struct.unpack_from("<IIIII", data, off)
        if ilt == 0 and name_rva == 0 and iat == 0:
            break
        no = rva_to_off(name_rva)
        if no is None:
            names.append("?")
        else:
            end = data.find(b"\x00", no)
            names.append(data[no:end].decode("ascii", "ignore"))
        off += 20
    return names


lib = Path(r"F:\job\open-webui\.venv\Lib\site-packages\torch\lib")
out = Path(r"F:\job\open-webui\redist\torch_dll_imports.txt")
lines = []
for p in sorted(lib.glob("*.dll")):
    lines.append(p.name + ": " + ", ".join(imports(p)))
out.write_text("\n".join(lines), encoding="utf-8")
print("wrote", out)
