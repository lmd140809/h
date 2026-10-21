# Báo cáo kiểm tra tương thích iOS 15–27.2

## Kết quả kiểm tra ZIP được gửi

- Có 56 tệp Swift.
- `IPHONEOS_DEPLOYMENT_TARGET` hiện là `16.0`.
- Kiểm tra cấu trúc ZIP: không phát hiện lỗi CRC.
- Chưa thể xác nhận build thành công: môi trường này không có Xcode/iOS SDK để biên dịch dự án.

## API cần xử lý cho iOS 15

| API | Vị trí phát hiện | Việc cần làm |
|---|---|---|
| `NavigationStack` | `helpers/DisplayIdentityAttribution.swift`, `views/FolderPatchSelectionView.swift`, `views/PatchProjectEditorView.swift`, `views/LogView.swift`, `views/WallpaperLabView.swift`, `views/SettingsView.swift`, `views/CleanerView.swift`, `views/AdminTabView.swift`, `views/FilesTabSwitcherView.swift`, `views/PatchProjectsView.swift`, `views/PatchUpdateSheet.swift`, `views/SharedComponents.swift` | Dùng `NavigationView` trên iOS 15; cần giữ đúng cấu trúc điều hướng từng màn hình. |
| `NavigationStack(path:)`, `NavigationPath` / điều hướng theo value | `views/AppDataBrowserView.swift`, `helpers/AppTabNavigationState.swift`, `views/FileBrowserView.swift` | Cần phương án điều hướng riêng cho iOS 15; thay `NavigationStack` đơn thuần sẽ không đủ. |
| `navigationDestination(for:)` | `views/AppDataBrowserView.swift`, `views/FileBrowserView.swift` | Thay hoặc bọc bằng điều hướng tương thích iOS 15, đồng thời kiểm tra mở thư mục và quay lại. |
| `LabeledContent` | `helpers/DisplayIdentityAttribution.swift`, `views/PatchProjectEditorView.swift`, `views/WallpaperLabView.swift`, `views/SettingsView.swift`, `views/CleanerView.swift`, `views/AdminTabView.swift`, `views/PatchProjectsView.swift` | Thay bằng `HStack`/view tương thích; một số trường hợp có nội dung view, không thể thay tự động an toàn. |
| `ShareLink` | `helpers/DisplayIdentityAttribution.swift`, `views/LogView.swift`, `views/FileBrowserView.swift`, `views/AdminTabView.swift` | Dùng `UIActivityViewController` qua `UIViewControllerRepresentable`, kiểm tra item là text hay URL. |
| `.presentationDetents` | `helpers/DisplayIdentityAttribution.swift` | Chỉ áp dụng trên iOS 16+; trên iOS 15 dùng sheet mặc định. |
| `.scrollDismissesKeyboard` | `helpers/LicenseActivationView.swift`, `views/FileBrowserView.swift`, `views/AppDataBrowserView.swift`, `views/CleanerView.swift` | Chỉ gọi trên iOS 16+ hoặc thay bằng modifier tương thích. |
| `.formStyle(.grouped)`, `.scrollContentBackground` | `helpers/DisplayIdentityAttribution.swift`, `views/SettingsView.swift` | Cần kiểm tra availability và cung cấp cách trình bày thay thế trên iOS 15. |

## Thay đổi cần thiết

1. Đổi `IPHONEOS_DEPLOYMENT_TARGET` của app target xuống `15.0` chỉ sau khi xử lý các API ở trên. Thay đổi target một mình không làm ứng dụng tương thích.
2. Xử lý toàn bộ API SwiftUI mới hơn deployment target, không chỉ các API liệt kê trong bảng.
3. Giữ nguyên quyền truy cập tệp được cấp bởi người dùng, kiểm tra đường dẫn, kiểm tra symlink, giới hạn kích thước, staging nguyên tử và rollback.
4. Wallpaper/file-system behavior phải được kiểm tra theo quyền thực tế của ứng dụng; thay đổi deployment target không cấp thêm quyền.
5. Không thể tuyên bố hỗ trợ iOS 27.2 nếu chưa build và kiểm thử trên SDK/thiết bị tương ứng. Giữ các nhánh chưa xác minh ở trạng thái không hỗ trợ.
6. Không mở rộng kernel exploit hoặc sandbox escape. Các phần đó cần được đánh giá riêng và không được coi là đã tương thích chỉ nhờ thay đổi giao diện.

## Trạng thái

Đây là báo cáo tĩnh dựa trên mã nguồn trong ZIP, không phải kết quả build hoặc kiểm thử thiết bị.
