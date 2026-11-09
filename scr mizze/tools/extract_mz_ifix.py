import struct, sys
sys.path.insert(0, "/home/tduck/Projects/MINHDUC/tools")
sys.path.insert(0, "/home/tduck/Projects/MINHDUC/tools/abhu")
import abhu_build as A
from ifix_patch import Reader

raw = open("/tmp/mz.raw", "rb").read()
info = A.parse_unityfs(raw)
print("AB blocks:", info["blocks"], "nodes:", info["nodes"])
data = b""
o = info["data_start"]
for us, cs, fl in info["blocks"]:
    data += raw[o:o + cs]
    o += cs
off, sz, fl, name = info["nodes"][0]
cab = data[off:off + sz]
no = cab.find(A.TEXTASSET_NAME + b"\x00")
nl = struct.unpack_from("<I", cab, no - 4)[0]
sl = A.align(no + nl, 4)
n = struct.unpack_from("<I", cab, sl)[0]
ifix = cab[sl + 4: sl + 4 + n]
open("/tmp/mz.ifix", "wb").write(ifix)
print("IFix bytes:", len(ifix))

r = Reader(ifix)
print("magic:", hex(r.u64()))
print("bridge:", r.s()[:80])
nt = r.i32()
print("types:", nt)
