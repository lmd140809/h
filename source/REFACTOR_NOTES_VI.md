# OGIOS source audit / refactor notes (Vietnamese)

## Đã chỉnh trong bản này
- Nút FF MAX không còn là nút giao diện bị khóa; nó thử mở URL scheme `freefiremax://`.
- Nút FF NORMAL tiếp tục thử mở `freefireth://`.
- Nếu iOS không mở được URL, ứng dụng hiển thị thông báo dễ hiểu và ghi kết quả vào log.
- Xóa helper giao diện `lockedLaunchButton` không còn được sử dụng.

## Giới hạn cần biết
- Đây là thay đổi mã nguồn, chưa phải IPA đã build. Môi trường hiện tại không có Xcode/iOS SDK nên chưa thể xác nhận build hoặc kiểm thử trên thiết bị thật.
- `UIApplication.open` trả về thành công chỉ xác nhận iOS xử lý URL scheme; không xác minh chắc chắn đúng bản game/region. Nếu `freefiremax://` không được game cài trên máy đăng ký, nút sẽ báo lỗi. Cần xác minh scheme chính thức của bản FF MAX bạn dùng.
- Patch engine (`PatchProjectLibrary`, `PatchPackageCodec`, `PatchTransaction`, `DevicePatchService`) chưa được sửa hoặc tuyên bố đã kiểm thử. Cần kiểm thử bằng một gói patch vô hại trong thư mục thử nghiệm trước khi dùng dữ liệu thật.
- Không chỉnh sửa hoặc kích hoạt exploit kernel/sandbox escape, anti-detection, hoặc các gói patch nhắm tới aimlock/cheat. Các phần đó cần được loại khỏi quy trình phát hành nếu mục tiêu là một trình quản lý patch an toàn.

## Luồng patch cần xác minh trên máy Mac/Xcode
1. Import gói thử nghiệm chỉ thay đổi một file do bạn sở hữu trong thư mục test.
2. Kiểm tra validator từ chối đường dẫn tuyệt đối, `..`, symlink và đường dẫn thoát khỏi root.
3. Áp dụng patch phải tạo backup/receipt trước khi thay file.
4. Xác minh hash và nội dung file sau patch.
5. Restore phải trả lại hash gốc; thử lỗi giữa chừng để xác minh rollback.
6. Thử receipt thiếu, backup bị sửa, file đích đã thay đổi ngoài dự kiến và quyền truy cập bị từ chối; UI phải báo lỗi rõ ràng và không báo thành công giả.

## FF MAX checklist
- Cài đúng phiên bản FF MAX và xác minh URL scheme trên thiết bị thật.
- Thử nút khi game đã cài, chưa cài, hoặc scheme không được đăng ký.
- Không suy ra khả năng patch FF MAX từ việc nút mở game thành công; bundle ID/container và định dạng gói patch phải được xác minh độc lập.
