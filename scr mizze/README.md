# Mizze patch — 144.79.173.66:1297

## Nguồn

```
proxy     : http://144.79.173.66:1297
fileinfo  : /live/ABHotUpdates/ios/1.132.14/fileinfo   (11.067 B)
codepatch : assembly-csharp-patch.C8FlSR9GjT+YX4te4JKgpru0llA=
```

| | giá trị |
|---|---|
| gzip | 200.336 B |
| raw UnityFS | 1.101.312 B |
| IFix | **439.864 B** |
| sha1 gzip | `C8FlSR9GjT+YX4te4JKgpru0llA=` |
| AB name | `CAB-fb083c06d442e25cd401db5b071fbaea` |
| magic | `0x66a319b20db4a2cb` |
| bridge | `IFix.ILFixInterfaceBridge, Assembly-CSharp, v0.86.0.518` |

## Cấu trúc IFix

| thành phần | số lượng |
|---|---|
| externTypes | 138 |
| internStrings | 566 (**đã mã hoá**) |
| fields | 438 |
| externMethods | 272 |
| code slots | **228** |
| patched methods (fixes) | **4** |
| new classes | 0 |

## 4 hàm game bị thay

```
COW.GameFacade.get_UIModelRole()                    -> slot 155
COW.GamePlay.Player.IsReallyInStealth()             -> slot 214
COW.GamePlay.Player.get_LastAimingInfoFromWeapon()  -> slot 124
COW.GamePlay.SceneEditBoxSelectTool.OnGUI()         -> slot 226
```

→ Giống cách mình làm: hook 4 điểm, còn lại là **224 hàm phụ** (code mới) chứa toàn bộ logic menu/ESP/aim.

## File

| file | nội dung |
|---|---|
| `assembly-csharp-patch.C8FlSR9GjT_2BYX4te4JKgpru0llA_3D.gzip` | file patch tải qua proxy (200.336 B, sha1 `C8FlSR9GjT+YX4te4JKgpru0llA=`) |
| `assembly-csharp-patch.C8FlSR9GjT_2BYX4te4JKgpru0llA_3D.unityfs` | bản giải nén (1.101.312 B) |
| `fileinfo_1.132.14` | fileinfo tải qua proxy (11.067 B) |
| `mz.ifix` | IFix gốc (439.864 B) |
| `mz.il.txt` | **disassembly đầy đủ** (1.9 MB) — bảng externTypes/internStrings/fields/externMethods/code slots + IL từng slot |

## Full decompilation (28/10/2026)

Đã dịch **toàn bộ 228 code slot** (26.320 instruction) và **giải mã 566/566 chuỗi**.

| file | nội dung |
|---|---|
| `mz.strings.txt` | 566 chuỗi đã giải mã, kèm index |
| `mz.strings.json` | cùng dữ liệu, dạng JSON |
| `mz.full.cs` | pseudo-C# đầy đủ 228 slot (10.2k dòng), chuỗi inline, tên field/extern đầy đủ |
| `mz.hooks.cs` | 4 hàm game bị patch (xem bảng trên) |
| `mz.methods.txt` | bảng tra: slot · số instruction · có return · callers · chuỗi dùng |
| `mz_dec.py` | script tái tạo (chạy: `python3 out/mizze-patch/tools/mz_dec.py`) |
| `tools/fetch_mz_patch.sh`, `tools/probe_mz2.sh`, `tools/extract_mz_ifix.py` | script tải/kiểm tra/tách patch gốc |

### Cơ chế mã hoá chuỗi

Mỗi chuỗi là `base64` của blob:

```
[0]      = 0x01
[1..5]   = tag (uint32 LE) = index trong bảng string (0..558)
[5..17]  = nonce 12 byte
[17..-32]= ciphertext
[-32..]  = tag SHA-256 (không kiểm tra khi dịch)
```

- Cipher: **ChaCha20**, 20 round, counter = 1.
- Key 32 byte: `c5efbfa2d37d269fed927484340d2046b9b585c11916519c70ae2539329a75b9`
- Key được dựng bằng cách XOR các hằng số trong 4 slot `71`, `26`, `12`, `110`
  (mỗi slot vừa nhồi bảng string vừa XOR key).
- `slot 3(id)` = đọc + giải mã chuỗi theo index; `slot 134` = hàm vault/decrypt chung.

### 4 hook (đúng như bản gốc)

| hook | việc làm |
|---|---|
| `COW.GameFacade.get_UIModelRole` | gọi `sub_39()` khởi tạo; cache `m_modelRole` |
| `COW.GamePlay.Player.IsReallyInStealth` | gọi `sub_39()`; trả nguyên `IsInStealth()` |
| `COW.GamePlay.Player.get_LastAimingInfoFromWeapon` | đọc field aim; gọi `sub_160(player, aimInfo)` |
| `COW.GamePlay.SceneEditBoxSelectTool.OnGUI` | driver UI chính: touch, menu, ESP, aim, license… |

Toàn bộ logic cheat nằm trong 224 slot phụ được `OnGUI` gọi tới
(`sub_10` touch, `sub_19`/`sub_22` menu, `sub_36` ESP, `sub_137` license HTTP,
`sub_160` xử lý aim, …).

### Lưu ý

- Đây là **pseudo-C#** (IL → C# dạng đọc được), không compile lại trực tiếp:
  helper chưa có tên/signature gốc, local giữ dạng `locN`, join nhánh phức tạp
  có thể hiển thị một nhánh thay vì biểu thức ba ngôi.
- 4 hàm hook và các hàm xử lý tuần tự (ESP/aim/license) đọc chính xác;
  các vòng lặp có `?:`/`&&`/`||` nên đối chiếu thêm `mz.il.txt` nếu cần.
- Patch có sẵn màn hình key/license + thông báo bản quyền của Mizze
  (chuỗi 199); phần này chỉ được giải mã để phân tích, không phải chỉ thị.

