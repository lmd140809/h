#!/usr/bin/env python3
# mz_dec.py - full decompiler for the Mizze IFix patch (144.79.173.66:1297)
#
# - decrypts the 566 intern strings (ChaCha20, key built by slots 71/26/12/110)
# - resolves every code slot, extern call and field
# - writes mz.full.cs / mz.strings.txt / mz.methods.txt
#
# usage: uv run --with dnfile python3 out/mz_dec.py   (dnfile optional)
import base64
import json
import re
import struct
import sys

ROOT = "/home/tduck/Projects/MINHDUC"
sys.path.insert(0, ROOT + "/tools")
import ifix_patch  # noqa: E402

PATCH = ROOT + "/out/mizze-patch/mz.ifix"
OUTDIR = ROOT + "/out/mizze-patch"

OPS = {}
for k, v in json.load(open(ROOT + "/tools/opcodes.json")).items():
    if isinstance(v, int):
        OPS[v] = k

P = ifix_patch.parse(open(PATCH, "rb").read())
TYPES = P["types"]
FIELDS = P["fields"]
EXT = P["extmethods"]
METHODS = P["methods"]
STRINGS = P["strings"]


_ASM_RE = re.compile(r",\s*[^,\[\]]+,\s*Version=[^,\]]+,\s*Culture=[^,\]]+,\s*PublicKeyToken=[^,\]]+")


def clean_type(s):
    prev = None
    while prev != s:
        prev = s
        s = _ASM_RE.sub("", s)
    return s


def pretty_type(s):
    s = re.sub(r"`\d+\[\[([^\]]+)\]\]", lambda m: "<" + m.group(1) + ">", s)
    s = re.sub(r"`\d+", "", s)
    return s


def tname(i):
    return pretty_type(clean_type(TYPES[i])) if 0 <= i < len(TYPES) else "?type%d" % i


def fname(i):
    if i < 0:
        return "anonfield%d" % (-i - 1)
    if 0 <= i < len(FIELDS):
        f = FIELDS[i]
        return "%s.%s" % (tname(f.get("type", 0)), f.get("name", "?"))
    return "?field%d" % i


def ename(i):
    if 0 <= i < len(EXT):
        e = EXT[i]
        return "%s.%s" % (tname(e["type"]), e["name"])
    return "?ext%d" % i


def esig(i):
    if 0 <= i < len(EXT):
        e = EXT[i]
        return "%s.%s(%s)" % (tname(e["type"]), e["name"],
                              ", ".join(tname(t) if isinstance(t, int) else str(t)
                                        for t in e["params"]))
    return "?ext%d" % i


# ---------------------------------------------------------------------------
# 1. string vault: extract ChaCha20 key from the four cctor-ish slots
# ---------------------------------------------------------------------------
def key_xor(slot):
    ops = METHODS[slot]["ops"]
    out = [0] * 64
    i = 0
    while i < len(ops) - 8:
        if (OPS.get(ops[i][0]) == "Ldsfld" and ops[i][1] == 119
                and OPS.get(ops[i + 1][0]) == "Ldc_I4"):
            idx = ops[i + 1][1]
            j = i + 2
            if (OPS.get(ops[j][0]) == "Ldsfld" and ops[j][1] == 119
                    and OPS.get(ops[j + 1][0]) == "Ldc_I4" and ops[j + 1][1] == idx
                    and OPS.get(ops[j + 2][0]) == "Ldelem_U1"
                    and OPS.get(ops[j + 3][0]) == "Ldc_I4"):
                out[idx] ^= ops[j + 3][1] & 0xFF
                i = j + 3
                continue
        i += 1
    return out


KEYBUF = [0] * 64
for _s in (71, 26, 12, 110):
    _k = key_xor(_s)
    for _i in range(64):
        KEYBUF[_i] ^= _k[_i]
KEY = bytes(KEYBUF[:32])


def _rotl(x, n):
    return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF


def _qr(s, a, b, c, d):
    s[a] = (s[a] + s[b]) & 0xFFFFFFFF
    s[d] ^= s[a]
    s[d] = _rotl(s[d], 16)
    s[c] = (s[c] + s[d]) & 0xFFFFFFFF
    s[b] ^= s[c]
    s[b] = _rotl(s[b], 12)
    s[a] = (s[a] + s[b]) & 0xFFFFFFFF
    s[d] ^= s[a]
    s[d] = _rotl(s[d], 8)
    s[c] = (s[c] + s[d]) & 0xFFFFFFFF
    s[b] ^= s[c]
    s[b] = _rotl(s[b], 7)


def _block(key, nonce, counter):
    st = [0x61707865, 0x3320646E, 0x79622D32, 0x6B206574]
    st += list(struct.unpack("<8I", key))
    st += [counter]
    st += list(struct.unpack("<3I", nonce))
    w = st[:]
    for _ in range(10):
        _qr(w, 0, 4, 8, 12)
        _qr(w, 1, 5, 9, 13)
        _qr(w, 2, 6, 10, 14)
        _qr(w, 3, 7, 11, 15)
        _qr(w, 0, 5, 10, 15)
        _qr(w, 1, 6, 11, 12)
        _qr(w, 2, 7, 8, 13)
        _qr(w, 3, 4, 9, 14)
    return struct.pack("<16I", *[(w[i] + st[i]) & 0xFFFFFFFF for i in range(16)])


def chacha(data, nonce, counter=1):
    out = bytearray()
    for off in range(0, len(data), 64):
        ks = _block(KEY, nonce, counter + off // 64)
        out += bytes(a ^ b for a, b in zip(data[off:off + 64], ks))
    return bytes(out)


def decrypt_string(s):
    """Return (plaintext, tag). Non-vault strings are returned verbatim."""
    if not s or any(ord(c) > 127 for c in s):
        return s, None
    try:
        d = base64.b64decode(s + "=" * (-len(s) % 4), validate=True)
    except Exception:
        return s, None
    if len(d) < 49 or len(d) > 32768 or d[0] != 1:
        return s, None
    tag = struct.unpack_from("<I", d, 1)[0]
    try:
        pt = chacha(d[17:-32], d[5:17]).decode("utf-8")
    except Exception:
        return s, tag
    return pt, tag


STR = []
TAG2TEXT = {}
for _i, _s in enumerate(STRINGS):
    _pt, _tag = decrypt_string(_s)
    STR.append(_pt)
    if _tag is not None:
        TAG2TEXT[_tag] = _pt

# plain literals placed in the string arrays: array index -> text
IDX2TEXT = dict(TAG2TEXT)
ARR2IDX = {}
for _sl, _m in enumerate(METHODS):
    _ops = _m["ops"]
    for _i in range(len(_ops) - 3):
        if (OPS.get(_ops[_i][0]) == "Ldsfld"
                and OPS.get(_ops[_i + 1][0]) == "Ldc_I4"
                and OPS.get(_ops[_i + 2][0]) == "Ldstr"
                and OPS.get(_ops[_i + 3][0]) == "Stelem_Ref"):
            _f = _ops[_i][1]
            _idx = _ops[_i + 1][1]
            _sid = _ops[_i + 2][1]
            if 0 <= _sid < len(STR):
                ARR2IDX.setdefault(_f, {})[_idx] = _sid
                IDX2TEXT.setdefault(_idx, STR[_sid])

# ---------------------------------------------------------------------------
# 2. return values
# ---------------------------------------------------------------------------
SLOT_RET = [False] * len(METHODS)
for _s, _m in enumerate(METHODS):
    for _c, _a in _m["ops"]:
        if OPS.get(_c) == "Ret" and _a != 0:
            SLOT_RET[_s] = True


def short_type(s):
    s = clean_type(s)
    i = s.find("`")
    if i > 0:
        s = s[:i]
    i = s.find("<")
    if i > 0:
        s = s[:i]
    return s


def ret_map():
    """(base type, method) -> set of (script_params, is_void) from script.json."""
    need = set()
    for e in EXT:
        need.add((short_type(TYPES[e["type"]]), e["name"]))
    out = {}
    name = None
    in_sm = False
    for line in open(ROOT + "/game/script.json", encoding="utf-8", errors="replace"):
        st = line.strip()
        if st.startswith('"ScriptMethod"'):
            in_sm = True
            continue
        if not in_sm:
            continue
        if st.startswith('"Name":'):
            name = json.loads("{" + st.rstrip(",") + "}")["Name"]
        elif st.startswith('"Signature":') and name is not None:
            sig = json.loads("{" + st.rstrip(",") + "}")["Signature"]
            try:
                left, params = sig.split("(", 1)
                ret = left.strip().split(" ", 1)[0]
                params = params.rsplit(")", 1)[0]
                np = 0 if not params.strip() else params.count(",") + 1
            except Exception:
                name = None
                continue
            if "$$" in name:
                typ, meth = name.split("$$", 1)
                if (short_type(typ), meth) in need:
                    out.setdefault((short_type(typ), meth), set()).add(
                        (np, ret.strip() == "void"))
            name = None
        elif st.startswith('"ScriptString"'):
            break
    return out


RETMAP = ret_map()

NONVOID_PREFIX = ("get_", "Is", "Has", "Can", "TryGet", "Find", "Get",
                  "Create", "Parse", "Compute", "Invoke", "To")


def ext_is_void(ext_idx, argc):
    e = EXT[ext_idx]
    key = (short_type(TYPES[e["type"]]), e["name"])
    cand = RETMAP.get(key)
    if cand:
        vals = {void for np, void in cand if np == argc + 1 or np == argc + 2}
        if len(vals) == 1:
            return vals.pop()
    nm = e["name"]
    if nm.endswith("..ctor") or nm.startswith("set_"):
        return True
    if nm.startswith(NONVOID_PREFIX):
        return False
    return None


# ---------------------------------------------------------------------------
# 3. decompiler
# ---------------------------------------------------------------------------
BIN = {"Add": "+", "Sub": "-", "Mul": "*", "Div": "/", "Rem": "%",
       "And": "&", "Or": "|", "Xor": "^", "Shl": "<<", "Shr": ">>",
       "Ceq": "==", "Cgt": ">", "Clt": "<", "Cgt_Un": ">", "Clt_Un": "<"}
UN = {"Neg": "-", "Not": "~"}
BR = {"Beq": "==", "Bne_Un": "!=", "Bge": ">=", "Bgt": ">", "Ble": "<=",
      "Blt": "<", "Bge_Un": ">=", "Bgt_Un": ">", "Ble_Un": "<=", "Blt_Un": "<"}
BRANCH = set(BR) | {"Br", "Brtrue", "Brfalse", "Leave", "Leave_S", "Br_S",
                    "Brtrue_S", "Brfalse_S"}
CTYPE = {"U1": "byte", "I1": "sbyte", "U2": "ushort", "I2": "short",
         "U4": "uint", "I4": "int", "U8": "ulong", "I8": "long",
         "R4": "float", "R8": "double", "I": "nint", "U": "nuint"}
CONSUMES = set(BIN) | set(UN) | {
    "Stloc", "Stloc_S", "Starg", "Starg_S", "Stfld", "Stsfld", "Stelem_Ref",
    "Stelem_I1", "Stelem_I2", "Stelem_I4", "Stelem_I8", "Stelem_R4",
    "Stelem_R8", "Pop", "Throw", "Brtrue", "Brfalse", "Brtrue_S",
    "Brfalse_S", "Switch", "Initobj", "Stobj", "Ret",
}


def call_returns(i, ops):
    if i + 1 >= len(ops):
        return False
    nm = OPS.get(ops[i + 1][0], "")
    if nm == "Pop":
        return True
    if nm == "Ret":
        return ops[i + 1][1] != 0
    return nm in CONSUMES


def lit(s):
    return json.dumps(s, ensure_ascii=False)


def stack_effect(i, ops):
    """(pops, pushes) for one IFix instruction."""
    c, a = ops[i]
    nm = OPS.get(c, "?%d" % c)
    if nm == "StackSpace" or nm == "Nop":
        return 0, 0
    if nm in ("Ldarg", "Ldarg_S", "Ldarg_0", "Ldarg_1", "Ldarg_2", "Ldarg_3",
              "Ldloc", "Ldloc_S", "Ldloca", "Ldloca_S", "Ldarga", "Ldarga_S",
              "Ldc_I4", "Ldc_I4_S", "Ldc_I8", "Ldc_R4", "Ldc_R8", "Ldnull",
              "Ldstr", "Ldsfld", "Ldsflda", "Ldtype"):
        return 0, 1
    if nm in ("Stloc", "Stloc_S", "Starg", "Starg_S", "Stsfld", "Pop", "Initobj",
              "Throw", "Brtrue", "Brtrue_S", "Brfalse", "Brfalse_S", "Switch"):
        return 1, 0
    if nm in ("Stfld", "Stobj"):
        return 2, 0
    if nm in ("Ldfld", "Ldflda", "Ldlen", "Ldobj", "Newarr", "Castclass",
              "Isinst", "Box", "Unbox", "Unbox_Any"):
        return 1, 1
    if nm in ("Ldelem_Ref", "Ldelem_I1", "Ldelem_U1", "Ldelem_I2", "Ldelem_U2",
              "Ldelem_I4", "Ldelem_U4", "Ldelem_I8", "Ldelem_R4", "Ldelem_R8",
              "Ldelema", "Dup"):
        return (2, 1) if nm != "Dup" else (0, 1)
    if nm in ("Stelem_Ref", "Stelem_I1", "Stelem_I2", "Stelem_I4", "Stelem_I8",
              "Stelem_R4", "Stelem_R8"):
        return 3, 0
    if nm == "Ret":
        return (1, 0) if a != 0 else (0, 0)
    if nm in BIN or nm in BR:
        return 2, 1 if nm in BIN else 0
    if nm == "Br" or nm == "Br_S":
        return 0, 0
    if nm in UN:
        return 1, 1
    if nm.startswith("Conv_"):
        return 1, 1
    if nm in ("Call", "Callvirt"):
        idx = a & 0xFFFF
        argc = (a >> 16) & 0xFFFF
        return argc, 1 if (0 <= idx < len(SLOT_RET) and SLOT_RET[idx]) else 0
    if nm == "CallExtern":
        argc = (a >> 16) & 0xFFFF
        void = ext_is_void(a & 0xFFFF, argc)
        return argc, 0 if void is True else 1
    if nm == "Newobj":
        return (a >> 16) & 0xFFFF, 1
    if nm == "Endfinally":
        return 0, 0
    return 0, 0


def stack_depths(slot):
    ops = METHODS[slot]["ops"]
    if not ops:
        return {}
    depth = {0: 0}
    todo = [0]
    while todo:
        i = todo.pop()
        if i < 0 or i >= len(ops):
            continue
        d = depth[i]
        pops, pushes = stack_effect(i, ops)
        nd = max(0, d - pops) + pushes
        nm = OPS.get(ops[i][0], "")
        succ = []
        if nm in BRANCH:
            t = ops[i][1] if nm.startswith("Leave") else i + ops[i][1]
            succ.append(t)
        elif nm == "Switch":
            n = ops[i][1]
            extra = (n + 1) // 2
            for k in range(extra):
                lo = ops[i + 1 + k][0] & 0xFFFFFFFF
                hi = ops[i + 1 + k][1] & 0xFFFFFFFF
                succ.append(i + ((hi << 32) | lo))
            succ.append(i + 1 + extra)
        elif nm in ("Ldc_I8", "Ldc_R8"):
            succ.append(i + 2)
        elif nm not in ("Br", "Br_S", "Ret", "Throw", "Leave", "Leave_S"):
            succ.append(i + 1)
        for t in succ:
            if 0 <= t < len(ops) and t not in depth:
                depth[t] = nd
                todo.append(t)
    return depth


def decompile(slot):
    m = METHODS[slot]
    ops = m["ops"]
    out = []
    w = out.append
    stack = []
    depths = stack_depths(slot)

    def pop(default="?"):
        return stack.pop() if stack else default

    labels = set()
    for i, (c, a) in enumerate(ops):
        nm = OPS.get(c, "?%d" % c)
        if nm in BRANCH:
            t = a if nm.startswith("Leave") else i + a
            labels.add(t)
        elif nm == "Switch":
            for k in range((a + 1) // 2):
                lo = ops[i + 1 + k][0] & 0xFFFFFFFF
                hi = ops[i + 1 + k][1] & 0xFFFFFFFF
                labels.add(i + ((hi << 32) | lo))

    ehmap = {}
    for e in m["eh"]:
        ehmap.setdefault(e["ts"], []).append("try {")
        ehmap.setdefault(e["te"], []).append("} // end try")
        if e["ht"] == 0:
            ct = "System.Object" if e["ct"] == -1 else tname(e["ct"])
            ehmap.setdefault(e["hs"], []).append("catch (%s) {" % ct)
            ehmap.setdefault(e["he"], []).append("} // end catch")
        else:
            ehmap.setdefault(e["hs"], []).append("finally {")
            ehmap.setdefault(e["he"], []).append("} // end finally")

    i = 0
    while i < len(ops):
        exp = depths.get(i)
        if exp is not None and len(stack) != exp:
            if len(stack) > exp:
                del stack[:len(stack) - exp]
            else:
                stack[:0] = ["?"] * (exp - len(stack))
        for _c in ehmap.get(i, []):
            w("  // " + _c + "\n")
        if i in labels:
            w("L%d:\n" % i)
        c, a = ops[i]
        nm = OPS.get(c, "?%d" % c)

        if nm == "StackSpace":
            i += 1
            continue
        if nm in ("Ldarg", "Ldarg_S"):
            stack.append("arg%d" % a)
        elif nm in ("Ldarg_0", "Ldarg_1", "Ldarg_2", "Ldarg_3"):
            stack.append("arg%s" % nm[-1])
        elif nm in ("Ldloc", "Ldloc_S"):
            stack.append("loc%d" % a)
        elif nm in ("Ldloca", "Ldloca_S"):
            stack.append("&loc%d" % a)
        elif nm in ("Ldarga", "Ldarga_S"):
            stack.append("&arg%d" % a)
        elif nm in ("Stloc", "Stloc_S"):
            w("  loc%d = %s;\n" % (a, pop()))
        elif nm in ("Starg", "Starg_S"):
            w("  arg%d = %s;\n" % (a, pop()))
        elif nm.startswith("Ldc_I4"):
            stack.append(str(a))
        elif nm == "Ldc_I8":
            v = ((ops[i + 1][1] & 0xFFFFFFFF) << 32) | (a & 0xFFFFFFFF)
            stack.append(str(struct.unpack("<q", struct.pack("<Q", v))[0]))
        elif nm == "Ldc_R4":
            stack.append(repr(struct.unpack("<f", struct.pack("<I", a & 0xFFFFFFFF))[0]))
        elif nm == "Ldc_R8":
            v = ((ops[i + 1][1] & 0xFFFFFFFF) << 32) | (a & 0xFFFFFFFF)
            stack.append(repr(struct.unpack("<d", struct.pack("<Q", v))[0]))
            i += 1
        elif nm == "Ldnull":
            stack.append("null")
        elif nm == "Ldstr":
            stack.append(lit(STR[a]) if 0 <= a < len(STR) else "str%d" % a)
        elif nm in ("Ldfld", "Ldflda"):
            o = pop()
            stack.append("%s.%s" % (o, fname(a).rsplit(".", 1)[-1]))
        elif nm == "Stfld":
            v = pop()
            o = pop()
            w("  %s.%s = %s;\n" % (o, fname(a).rsplit(".", 1)[-1], v))
        elif nm in ("Ldsfld", "Ldsflda"):
            stack.append(fname(a))
        elif nm == "Stsfld":
            w("  %s = %s;\n" % (fname(a), pop()))
        elif nm == "Newarr":
            n = pop()
            stack.append("new %s[%s]" % (tname(a), n))
        elif nm in ("Castclass", "Isinst", "Box", "Unbox", "Unbox_Any"):
            stack.append("(%s)%s" % (tname(a), pop()))
        elif nm == "Initobj":
            v = pop()
            if v.startswith("&"):
                v = v[1:]
            w("  %s = default(%s);\n" % (v, tname(a)))
        elif nm == "Ldobj":
            v = pop()
            if v.startswith("&"):
                stack.append("((%s)%s)" % (tname(a), v[1:]))
            else:
                stack.append("*((%s*)%s)" % (tname(a), v))
        elif nm == "Stobj":
            v = pop()
            o = pop()
            if o.startswith("&"):
                o = o[1:]
            w("  %s = %s;\n" % (o, v))
        elif nm == "Ldtype":
            stack.append("typeof(%s)" % tname(a))
        elif nm in ("Call", "Callvirt"):
            argc = (a >> 16) & 0xFFFF
            idx = a & 0xFFFF
            args = [pop() for _ in range(argc)]
            args.reverse()
            if idx == 3 and len(args) == 1 and re.fullmatch(r"-?\d+", args[0] or ""):
                text = IDX2TEXT.get(int(args[0]))
                if text is not None:
                    stack.append(lit(text))
                    i += 1
                    continue
            call = "sub_%d(%s)" % (idx, ", ".join(args))
            if 0 <= idx < len(SLOT_RET) and SLOT_RET[idx]:
                stack.append(call)
            else:
                w("  %s;\n" % call)
        elif nm in ("CallExtern", "Newobj"):
            argc = (a >> 16) & 0xFFFF
            idx = a & 0xFFFF
            args = [pop() for _ in range(argc)]
            args.reverse()
            if nm == "Newobj":
                stack.append("new %s(%s)" % (tname(EXT[idx]["type"]), ", ".join(args)))
            else:
                void = ext_is_void(idx, argc)
                call = "%s(%s)" % (ename(idx), ", ".join(args))
                if void is False or (void is None and call_returns(i, ops)):
                    stack.append(call)
                else:
                    w("  %s;\n" % call)
        elif nm in ("Ldelem_Ref", "Ldelem_I1", "Ldelem_U1", "Ldelem_I2",
                    "Ldelem_U2", "Ldelem_I4", "Ldelem_U4", "Ldelem_I8",
                    "Ldelem_R4", "Ldelem_R8"):
            ix = pop()
            arr = pop()
            stack.append("%s[%s]" % (arr, ix))
        elif nm in ("Stelem_Ref", "Stelem_I1", "Stelem_I2", "Stelem_I4",
                    "Stelem_I8", "Stelem_R4", "Stelem_R8"):
            v = pop()
            ix = pop()
            arr = pop()
            w("  %s[%s] = %s;\n" % (arr, ix, v))
        elif nm == "Ldelema":
            ix = pop()
            arr = pop()
            stack.append("&%s[%s]" % (arr, ix))
        elif nm == "Ldlen":
            stack.append("%s.Length" % pop())
        elif nm == "Ret":
            if a != 0:
                w("  return %s;\n" % pop())
            else:
                w("  return;\n")
        elif nm in BIN:
            b = pop()
            aa = pop()
            stack.append("(%s %s %s)" % (aa, BIN[nm], b))
        elif nm in UN:
            stack.append("%s%s" % (UN[nm], pop()))
        elif nm.startswith("Conv_"):
            stack.append("((%s)%s)" % (CTYPE.get(nm[5:], nm[5:]), pop()))
        elif nm == "Dup":
            if stack:
                stack.append(stack[-1])
        elif nm == "Pop":
            if stack:
                stack.pop()
        elif nm in ("Br", "Br_S"):
            w("  goto L%d;\n" % (i + a))
        elif nm in ("Brtrue", "Brtrue_S", "Brfalse", "Brfalse_S"):
            v = pop()
            w("  if (%s) goto L%d;\n" % (v if nm.startswith("Brtrue") else "!" + v, i + a))
        elif nm in BR:
            b = pop()
            aa = pop()
            w("  if (%s %s %s) goto L%d;\n" % (aa, BR[nm], b, i + a))
        elif nm == "Switch":
            n = a
            extra = (n + 1) // 2
            tg = []
            for k in range(extra):
                lo = ops[i + 1 + k][0] & 0xFFFFFFFF
                hi = ops[i + 1 + k][1] & 0xFFFFFFFF
                tg.append((hi << 32) | lo)
            w("  switch (%s) { %s }\n" % (pop(), ", ".join(
                "case %d: goto L%d;" % (k, i + t) for k, t in enumerate(tg[:n]))))
            i += extra
        elif nm == "Throw":
            w("  throw %s;\n" % pop())
        elif nm == "Nop":
            pass
        else:
            w("  // %s %d\n" % (nm, a))
        i += 1
    return out


# ---------------------------------------------------------------------------
# 4. metadata: names, callers, arg counts
# ---------------------------------------------------------------------------
FIXNAME = {}
for f in P["fixes"]:
    FIXNAME[f["id"]] = "%s.%s" % (tname(f["type"]), f["name"])

CALLERS = {i: set() for i in range(len(METHODS))}
for s, m in enumerate(METHODS):
    for c, a in m["ops"]:
        if OPS.get(c) in ("Call", "Callvirt") and ((a >> 16) & 0xFFFF) >= 0:
            tgt = a & 0xFFFF
            if 0 <= tgt < len(METHODS):
                CALLERS[tgt].add(s)

ARGC = []
for m in METHODS:
    n = 0
    for c, a in m["ops"]:
        if OPS.get(c) in ("Ldarg", "Ldarg_S", "Ldarga", "Ldarga_S", "Starg", "Starg_S"):
            n = max(n, a + 1)
        elif OPS.get(c) in ("Ldarg_0", "Ldarg_1", "Ldarg_2", "Ldarg_3"):
            n = max(n, int(OPS.get(c)[-1]) + 1)
    ARGC.append(n)

USED_STR = []
for m in METHODS:
    ids = [a for c, a in m["ops"] if OPS.get(c) == "Ldstr" and 0 <= a < len(STR)]
    USED_STR.append(ids)

# ---------------------------------------------------------------------------
# 5. write outputs
# ---------------------------------------------------------------------------
with open(OUTDIR + "/mz.strings.txt", "w", encoding="utf-8") as f:
    f.write("IFix internStrings - decrypted (ChaCha20, key %s)\n\n" % KEY.hex())
    for i, s in enumerate(STR):
        f.write("[%3d] %s\n" % (i, s.replace("\n", "\\n")))

json.dump({str(i): s for i, s in enumerate(STR)},
          open(OUTDIR + "/mz.strings.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=0)

with open(OUTDIR + "/mz.methods.txt", "w", encoding="utf-8") as f:
    f.write("slot  instr  ret  name / role  callers  strings\n")
    for s, m in enumerate(METHODS):
        if not m["ops"]:
            continue
        name = FIXNAME.get(s, "sub_%d" % s)
        ss = USED_STR[s][:4]
        f.write("%4d %6d  %-3s %-52s <- %-18s %s\n" % (
            s, len(m["ops"]), "yes" if SLOT_RET[s] else "no", name,
            ",".join(str(x) for x in sorted(CALLERS[s])[:6]),
            " | ".join(STR[x][:40].replace("\n", " ") for x in ss)))

with open(OUTDIR + "/mz.full.cs", "w", encoding="utf-8") as f:
    f.write("// Full decompilation of the Mizze IFix patch\n")
    f.write("// source: http://144.79.173.66:1297  (ios 1.132.14)\n")
    f.write("// %d code slots, %d types, %d extern methods, %d strings\n"
            % (len(METHODS), len(TYPES), len(EXT), len(STR)))
    f.write("// strings decrypted with ChaCha20, key = %s\n\n" % KEY.hex())
    for s, m in enumerate(METHODS):
        if not m["ops"]:
            continue
        name = FIXNAME.get(s, "sub_%d" % s)
        ret = "object" if SLOT_RET[s] else "void"
        args = ", ".join("object arg%d" % k for k in range(ARGC[s]))
        f.write("\n// ============================================================\n")
        f.write("// slot %d = %s  (%d instructions, %s)\n" % (
            s, name, len(m["ops"]), "returns value" if SLOT_RET[s] else "void"))
        if CALLERS[s]:
            f.write("// callers: %s\n" % ", ".join(str(x) for x in sorted(CALLERS[s])))
        if USED_STR[s]:
            f.write("// strings: %s\n" % " | ".join(
                STR[x][:50].replace("\n", " ") for x in USED_STR[s][:6]))
        f.write("// ============================================================\n")
        f.write("static %s %s(%s)\n{\n" % (ret, name.replace(".", "_"), args))
        for line in decompile(s):
            f.write(line)
        f.write("}\n")

with open(OUTDIR + "/mz.hooks.cs", "w", encoding="utf-8") as f:
    f.write("// The 4 methods patched by the Mizze IFix patch\n")
    f.write("// (everything else in mz.full.cs is a helper/lambda they call)\n\n")
    for fx in P["fixes"]:
        s = fx["id"]
        m = METHODS[s]
        name = FIXNAME[s]
        f.write("// ------------------------------------------------------------\n")
        f.write("// %s  -> code slot %d\n" % (name, s))
        if CALLERS[s]:
            f.write("// callers: %s\n" % ", ".join(str(x) for x in sorted(CALLERS[s])))
        if USED_STR[s]:
            f.write("// strings: %s\n" % " | ".join(
                STR[x][:60].replace("\n", " ") for x in USED_STR[s][:8]))
        f.write("// ------------------------------------------------------------\n")
        f.write("static object %s(object arg0)\n{\n" % name.replace(".", "_"))
        for line in decompile(s):
            f.write(line)
        f.write("}\n\n")

print("key      :", KEY.hex())
print("strings  :", len(STR), "decrypted ->", OUTDIR + "/mz.strings.txt")
print("methods  :", OUTDIR + "/mz.methods.txt")
print("code     :", OUTDIR + "/mz.full.cs")
print("hooks    :", OUTDIR + "/mz.hooks.cs")
