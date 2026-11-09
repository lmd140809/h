# MizzeRebuild iOS — bộ khung SwiftUI

Đây là ứng dụng iOS độc lập dạng starter project. Nó **không phải** bản rebuild/khôi phục patch Unity/IFix trong `scr mizze.zip`, không chứa hook, ESP, tự động ngắm hoặc mã can thiệp gameplay. Màn hình KEY hiện chỉ là giao diện mẫu, chưa gọi API thật.

## Build bằng iPhone qua GitHub Actions

1. Tải ZIP này và giải nén trên iPhone (ứng dụng Tệp).
2. Trên Safari mở https://github.com/new và tạo repository mới, ví dụ `MizzeRebuild`. Chọn Public hoặc Private.
3. Trong repository, chọn **Add file → Upload files**.
4. Tải lên toàn bộ nội dung đã giải nén, bao gồm thư mục `.github` (nếu không thấy `.github`, bật hiển thị file ẩn hoặc tạo file workflow trực tiếp trên GitHub theo đường dẫn `.github/workflows/ios.yml`).
5. Nhấn **Commit changes**.
6. Mở tab **Actions** → workflow **Build iOS app** → **Run workflow** (hoặc đợi lần push chạy xong).
7. Khi có dấu tick xanh, mở lần chạy đó, kéo xuống **Artifacts**, tải `MizzeRebuild-unsigned-iOS-app`.

## Quan trọng về Apple ID miễn phí

GitHub Actions trong cấu hình này chỉ biên dịch và đóng gói `.app` **chưa ký**. File ZIP artifact không thể cài trực tiếp lên iPhone. Apple ID miễn phí không biến file build trên GitHub thành IPA đã ký; ký bằng tài khoản miễn phí thường cần Xcode trên máy Mac đã đăng nhập Apple ID, provisioning profile phù hợp và việc làm mới chữ ký định kỳ. Muốn cài trực tiếp/phân phối thuận tiện cần quy trình ký hợp lệ; Apple Developer Program trả phí hỗ trợ phân phối rộng hơn.

## Chỉnh sửa

- Giao diện: `MizzeRebuild/ContentView.swift`
- Điểm khởi chạy: `MizzeRebuild/MizzeRebuildApp.swift`
- Cấu hình dự án: `project.yml`
- Build tự động: `.github/workflows/ios.yml`

Đổi `com.example.MizzeRebuild` trong `project.yml` thành Bundle Identifier riêng trước khi chuẩn bị ký/phân phối.

## Nếu workflow lỗi

Mở lần chạy trong Actions → chọn job `build` → mở bước có dấu X đỏ → sao chép phần log lỗi và gửi lại để được hỗ trợ.
