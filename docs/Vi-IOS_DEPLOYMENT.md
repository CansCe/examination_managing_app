# Hướng Dẫn Triển Khai iOS

Hướng dẫn này cung cấp hướng dẫn từng bước để triển khai Ứng Dụng Quản Lý Thi lên thiết bị iOS và App Store.

## 📋 Điều Kiện Tiên Quyết

### Tài Khoản và Phần Mềm Bắt Buộc

1. **Tài Khoản Apple Developer**
   - Đăng ký [Chương Trình Apple Developer](https://developer.apple.com/programs/) ($99/năm)
   - Bắt buộc để phân phối App Store
   - Tài khoản miễn phí cho phép phát triển và kiểm thử TestFlight

2. **Máy Tính macOS**
   - macOS 12.0 trở lên
   - Bắt buộc để xây dựng ứng dụng iOS (Flutter iOS builds yêu cầu macOS)

3. **Xcode**
   - Xcode 14.0 trở lên (khuyến nghị: phiên bản mới nhất)
   - Cài đặt từ Mac App Store hoặc [Apple Developer Downloads](https://developer.apple.com/download/)
   - Bao gồm iOS SDK, trình giả lập và công cụ phát triển

4. **Flutter SDK**
   - Flutter 3.2.3 trở lên
   - Xác minh cài đặt: `flutter doctor`

5. **CocoaPods** (cho phụ thuộc iOS)
   - Cài đặt: `sudo gem install cocoapods`
   - Xác minh: `pod --version`

### Xác Minh Điều Kiện Tiên Quyết

```bash
# Kiểm tra cài đặt Flutter
flutter doctor

# Kiểm tra cài đặt Xcode
xcodebuild -version

# Kiểm tra CocoaPods
pod --version

# Kiểm tra tài khoản Apple Developer
# (Đăng nhập vào developer.apple.com để xác minh)
```

**Kết quả `flutter doctor` mong đợi:**
```
[✓] Flutter (Channel stable, 3.2.3, ...)
[✓] Xcode - develop for iOS and macOS (Xcode 14.x)
[✓] CocoaPods version 1.x.x
[✓] Connected device (iOS simulator or physical device)
```

## 🔧 Cấu Hình Trước Triển Khai

### Bước 1: Cấu Hình Bundle Identifier

Bundle identifier phải là duy nhất và khớp với tài khoản Apple Developer của bạn.

**Tệp:** `ios/Runner.xcodeproj/project.pbxproj`

Bundle identifier hiện tại: `com.pea.examManagementApp`

**Để thay đổi:**
1. Mở `ios/Runner.xcodeproj` trong Xcode
2. Chọn "Runner" trong trình điều hướng dự án
3. Chọn target "Runner"
4. Đi đến tab "Signing & Capabilities"
5. Cập nhật "Bundle Identifier" thành định danh duy nhất của bạn (ví dụ: `com.yourcompany.examManagementApp`)

**Hoặc chỉnh sửa trực tiếp trong cài đặt dự án Xcode:**
- Product → Scheme → Edit Scheme
- Hoặc sửa `PRODUCT_BUNDLE_IDENTIFIER` trong build settings

### Bước 2: Cấu Hình Tên Hiển Thị Ứng Dụng

**Tệp:** `ios/Runner/Info.plist`

Tên hiển thị đã được đặt là "Exam Management App". Để thay đổi:

```xml
<key>CFBundleDisplayName</key>
<string>Tên Ứng Dụng Của Bạn</string>
```

### Bước 3: Cấu Hình Phiên Bản và Số Build

**Tệp:** `pubspec.yaml`

```yaml
version: 1.0.0+1
# Định dạng: tên_phiên_bản+số_build
# tên_phiên_bản: 1.0.0 (hiển thị cho người dùng)
# số_build: 1 (tăng cho mỗi lần gửi App Store)
```

**Quan Trọng:**
- Tăng `số_build` (+1) cho mỗi lần gửi App Store
- Cập nhật `tên_phiên_bản` cho bản phát hành chính/phụ (ví dụ: 1.0.0 → 1.1.0)

### Bước 4: Cấu Hình Biểu Tượng Ứng Dụng và Màn Hình Khởi Động

**Biểu Tượng Ứng Dụng:**
1. Chuẩn bị biểu tượng ứng dụng ở các kích thước yêu cầu (1024x1024 cho App Store)
2. Đặt tệp biểu tượng trong `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
3. Hoặc sử dụng trình tạo App Icon của Xcode

**Màn Hình Khởi Động:**
- Màn hình khởi động hiện tại: `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Tùy chỉnh nếu cần cho thương hiệu

### Bước 5: Cấu Hình Endpoint API

**Tệp:** `lib/services/api_discovery_service.dart`

Đảm bảo URL API sản xuất được cấu hình:

```dart
static final List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',  // HTTPS sản xuất
  'http://exam-app-api.duckdns.org',    // HTTP dự phòng
];

static final List<String> _defaultChatUrls = [
  'https://backend-chat.duckdns.org',   // HTTPS sản xuất
  'http://backend-chat.duckdns.org',    // HTTP dự phòng
];
```

### Bước 6: Cấu Hình App Transport Security (ATS)

iOS yêu cầu HTTPS cho yêu cầu mạng. Cấu hình ATS trong `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>exam-app-api.duckdns.org</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        <key>backend-chat.duckdns.org</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Lưu Ý:** Nếu sử dụng HTTPS (được khuyến nghị), bạn có thể xóa ngoại lệ ATS. Cấu hình trên thực thi HTTPS.

### Bước 7: Cài Đặt Phụ Thuộc iOS

```bash
cd ios
pod install
cd ..
```

**Kết Quả Mong Đợi:**
```
Analyzing dependencies
Downloading dependencies
Installing [dependencies]
Generating Pods project
```

## 🏗️ Xây Dựng Cho iOS

### Bước 1: Dọn Dẹp Build Trước

```bash
# Dọn dẹp build Flutter
flutter clean

# Dọn dẹp build iOS (tùy chọn)
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### Bước 2: Lấy Phụ Thuộc

```bash
flutter pub get
```

### Bước 3: Xây Dựng Ứng Dụng iOS

#### Tùy Chọn A: Xây Dựng Cho Kiểm Thử Thiết Bị

```bash
# Xây dựng cho thiết bị iOS đã kết nối
flutter build ios --release

# Hoặc xây dựng cho thiết bị cụ thể
flutter build ios --release --device-id=<device-id>
```

#### Tùy Chọn B: Xây Dựng Cho Phân Phối App Store

```bash
# Xây dựng ứng dụng iOS cho App Store
flutter build ios --release --no-codesign
```

**Lưu Ý:** `--no-codesign` xây dựng ứng dụng mà không ký mã. Bạn sẽ ký nó trong Xcode.

### Bước 4: Mở Trong Xcode

```bash
open ios/Runner.xcworkspace
```

**Quan Trọng:** Luôn mở `.xcworkspace`, không phải `.xcodeproj` (yêu cầu CocoaPods)

## 🔐 Ký Mã và Chứng Chỉ

### Bước 1: Tạo App ID Trong Apple Developer Portal

1. Đi đến [Apple Developer Portal](https://developer.apple.com/account/)
2. Điều hướng đến "Certificates, Identifiers & Profiles"
3. Nhấp "Identifiers" → "+" → "App IDs"
4. Chọn "App"
5. Nhập:
   - **Mô Tả**: Exam Management App
   - **Bundle ID**: `com.pea.examManagementApp` (hoặc ID tùy chỉnh của bạn)
6. Bật các khả năng yêu cầu (Push Notifications, nếu cần)
7. Nhấp "Continue" → "Register"

### Bước 2: Tạo Chứng Chỉ Phân Phối

1. Trong Apple Developer Portal → "Certificates"
2. Nhấp "+" để tạo chứng chỉ mới
3. Chọn "Apple Distribution" (cho App Store)
4. Làm theo hướng dẫn để tạo Certificate Signing Request (CSR):
   - Mở Keychain Access trên Mac
   - Keychain Access → Certificate Assistant → Request a Certificate
   - Nhập email và tên
   - Lưu vào đĩa
5. Tải lên CSR lên Apple Developer Portal
6. Tải xuống chứng chỉ và nhấp đúp để cài đặt trong Keychain

### Bước 3: Tạo Provisioning Profile

1. Trong Apple Developer Portal → "Profiles"
2. Nhấp "+" → "App Store" distribution
3. Chọn App ID của bạn
4. Chọn Chứng Chỉ Phân Phối của bạn
5. Nhập tên profile: "Exam Management App Distribution"
6. Tải xuống và nhấp đúp để cài đặt

### Bước 4: Cấu Hình Ký Mã Trong Xcode

1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Chọn dự án "Runner" trong trình điều hướng
3. Chọn target "Runner"
4. Đi đến tab "Signing & Capabilities"
5. **Cho Phát Triển:**
   - Chọn "Automatically manage signing"
   - Chọn Team của bạn (tài khoản Apple Developer)
   - Xcode sẽ tự động tạo chứng chỉ và profile

6. **Cho Phân Phối App Store:**
   - Bỏ chọn "Automatically manage signing" (tùy chọn)
   - Chọn "Manual" signing
   - Chọn Provisioning Profile Phân Phối của bạn
   - Chọn Chứng Chỉ Phân Phối của bạn

## 📦 Tạo Archive Cho App Store

### Bước 1: Cấu Hình Build Settings

1. Trong Xcode, chọn scheme "Runner"
2. Product → Scheme → Edit Scheme
3. Chọn "Archive" trong thanh bên trái
4. Đặt "Build Configuration" thành "Release"

### Bước 2: Chọn Generic iOS Device

1. Trong thanh công cụ Xcode, chọn đích
2. Chọn "Any iOS Device (arm64)" hoặc "Generic iOS Device"
3. **Quan Trọng:** Không chọn trình giả lập (không thể archive cho trình giả lập)

### Bước 3: Archive Ứng Dụng

1. Product → Archive
2. Đợi build hoàn tất (có thể mất vài phút)
3. Cửa sổ Organizer sẽ mở tự động

**Nếu Archive bị vô hiệu:**
- Đảm bảo bạn đã chọn "Generic iOS Device" hoặc "Any iOS Device"
- Kiểm tra "Release" configuration được chọn
- Xác minh ký mã được cấu hình đúng

### Bước 4: Xác Minh Archive

1. Trong Organizer, chọn archive của bạn
2. Nhấp "Validate App"
3. Đăng nhập bằng Apple ID của bạn
4. Chọn phương thức phân phối: "App Store Connect"
5. Chọn team của bạn
6. Xem lại thông tin ứng dụng
7. Nhấp "Validate"

**Sửa mọi lỗi xác minh trước khi phân phối.**

### Bước 5: Phân Phối Lên App Store

1. Trong Organizer, chọn archive đã xác minh của bạn
2. Nhấp "Distribute App"
3. Chọn "App Store Connect"
4. Chọn tùy chọn phân phối:
   - **Upload**: Tải lên App Store Connect (được khuyến nghị)
   - **Export**: Xuất tệp .ipa (để tải lên thủ công)
5. Chọn phương thức phân phối: "Upload"
6. Xem lại thông tin ứng dụng
7. Chọn tùy chọn ký mã:
   - **Automatically manage signing** (được khuyến nghị)
   - Hoặc chọn chứng chỉ phân phối của bạn thủ công
8. Nhấp "Upload"
9. Đợi tải lên hoàn tất

## 📱 Thiết Lập App Store Connect

### Bước 1: Tạo Bản Ghi Ứng Dụng

1. Đi đến [App Store Connect](https://appstoreconnect.apple.com/)
2. Điều hướng đến "My Apps"
3. Nhấp "+" → "New App"
4. Điền thông tin ứng dụng:
   - **Platform**: iOS
   - **Name**: Exam Management App
   - **Primary Language**: English (hoặc ngôn ngữ của bạn)
   - **Bundle ID**: Chọn App ID của bạn
   - **SKU**: Định danh duy nhất (ví dụ: `exam-management-app-001`)
   - **User Access**: Full Access (hoặc Limited Access)
5. Nhấp "Create"

### Bước 2: Cấu Hình Thông Tin Ứng Dụng

#### Tab Thông Tin Ứng Dụng

- **Name**: Exam Management App
- **Subtitle**: (Tùy chọn) Mô tả ngắn
- **Category**: Education
- **Content Rights**: Chọn tùy chọn phù hợp
- **Age Rating**: Hoàn tất bảng câu hỏi

#### Giá và Khả Năng Truy Cập

- Đặt giá (Miễn phí hoặc Trả phí)
- Chọn quốc gia/khu vực
- Đặt ngày khả dụng

#### Quyền Riêng Tư Ứng Dụng

- Hoàn tất bảng câu hỏi quyền riêng tư
- Thêm URL chính sách quyền riêng tư (bắt buộc)
- Mô tả thực hành thu thập dữ liệu

### Bước 3: Chuẩn Bị Danh Sách App Store

#### Ảnh Chụp Màn Hình App Store

Kích thước yêu cầu:
- **Màn Hình 6.7" (iPhone 14 Pro Max)**: 1290 x 2796 pixel
- **Màn Hình 6.5" (iPhone 11 Pro Max)**: 1242 x 2688 pixel
- **Màn Hình 5.5" (iPhone 8 Plus)**: 1242 x 2208 pixel

**Yêu Cầu Ảnh Chụp Màn Hình:**
- Ít nhất 1 ảnh chụp màn hình cho mỗi kích thước thiết bị
- Tối đa 10 ảnh chụp màn hình cho mỗi kích thước thiết bị
- Định dạng PNG hoặc JPEG
- Không có độ trong suốt

#### Video Xem Trước Ứng Dụng (Tùy Chọn)

- 15-30 giây
- Hiển thị chức năng ứng dụng
- Định dạng MP4, MOV hoặc M4V

#### Mô Tả

- **Name**: Exam Management App (tối đa 30 ký tự)
- **Subtitle**: (Tùy chọn, tối đa 30 ký tự)
- **Description**: Mô tả ứng dụng chi tiết (tối đa 4000 ký tự)
- **Keywords**: Từ khóa phân tách bằng dấu phẩy (tối đa 100 ký tự)
- **Support URL**: Trang web hỗ trợ của bạn
- **Marketing URL**: (Tùy chọn) Trang web tiếp thị
- **Promotional Text**: (Tùy chọn, 170 ký tự) Có thể cập nhật mà không cần gửi mới

#### Thông Tin Phiên Bản

- **Version**: 1.0.0 (khớp với pubspec.yaml)
- **Copyright**: Thông báo bản quyền của bạn
- **What's New**: Ghi chú phát hành cho phiên bản này

### Bước 4: Gửi Để Xem Xét

1. Sau khi tải lên build, đi đến tab "App Store"
2. Chọn phiên bản build trong phần "iOS App"
3. Hoàn tất tất cả thông tin bắt buộc (đánh dấu *)
4. Trả lời câu hỏi tuân thủ xuất khẩu
5. Nhấp "Submit for Review"
6. Đợi xem xét của Apple (thường 24-48 giờ)

## 🧪 Kiểm Thử Trước Khi Gửi

### TestFlight (Kiểm Thử Beta)

1. **Tải Lên Build Lên TestFlight**
   - Archive và tải lên như mô tả ở trên
   - Build sẽ xuất hiện trong TestFlight sau khi xử lý (10-30 phút)

2. **Thêm Người Kiểm Thử Nội Bộ**
   - Đi đến App Store Connect → TestFlight
   - Thêm người kiểm thử nội bộ (tối đa 100, phải trong team của bạn)
   - Họ có thể kiểm thử ngay sau khi build được xử lý

3. **Thêm Người Kiểm Thử Bên Ngoài**
   - Tạo nhóm kiểm thử bên ngoài
   - Thêm người kiểm thử (tối đa 10,000)
   - Yêu cầu Beta App Review (24-48 giờ)
   - Người kiểm thử nhận email mời

4. **Kiểm Thử Trên Thiết Bị Vật Lý**
   - Cài đặt ứng dụng TestFlight trên thiết bị iOS
   - Chấp nhận lời mời
   - Cài đặt và kiểm thử ứng dụng

### Kiểm Thử Thiết Bị Cục Bộ

```bash
# Kết nối thiết bị iOS qua USB
# Bật Chế Độ Nhà Phát Triển trên thiết bị (Settings → Privacy & Security → Developer Mode)

# Xây dựng và chạy trên thiết bị
flutter run --release

# Hoặc xây dựng và cài đặt
flutter build ios --release
# Sau đó cài đặt qua Xcode hoặc Apple Configurator
```

## 🔍 Danh Sách Kiểm Tra Trước Khi Gửi

### Mã và Cấu Hình

- [ ] Bundle identifier là duy nhất và đã đăng ký
- [ ] Phiên bản và số build đúng
- [ ] Biểu tượng ứng dụng được cung cấp ở tất cả kích thước yêu cầu
- [ ] Màn hình khởi động được cấu hình
- [ ] Endpoint API là URL sản xuất (HTTPS)
- [ ] App Transport Security được cấu hình
- [ ] Tất cả phụ thuộc được cập nhật
- [ ] Mã sạch (không có mã debug, dữ liệu thử nghiệm, v.v.)

### App Store Connect

- [ ] Bản ghi ứng dụng được tạo
- [ ] Tất cả thông tin ứng dụng bắt buộc được điền
- [ ] Ảnh chụp màn hình được cung cấp cho tất cả kích thước thiết bị yêu cầu
- [ ] Mô tả ứng dụng hoàn chỉnh và chính xác
- [ ] URL chính sách quyền riêng tư được cung cấp
- [ ] Bảng câu hỏi xếp hạng độ tuổi được hoàn tất
- [ ] Câu hỏi tuân thủ xuất khẩu được trả lời

### Kiểm Thử

- [ ] Ứng dụng được kiểm thử trên thiết bị iOS vật lý
- [ ] Tất cả tính năng hoạt động đúng
- [ ] Kết nối API hoạt động với endpoint sản xuất
- [ ] Chức năng chat hoạt động
- [ ] Không có sự cố hoặc lỗi nghiêm trọng
- [ ] Kiểm thử TestFlight hoàn tất (nếu sử dụng)

### Pháp Lý và Tuân Thủ

- [ ] Chính sách quyền riêng tư có thể truy cập
- [ ] Điều khoản dịch vụ (nếu áp dụng)
- [ ] Yêu cầu tuân thủ xuất khẩu được đáp ứng
- [ ] Quyền nội dung chính xác
- [ ] Xếp hạng độ tuổi phù hợp

## 🐛 Khắc Phục Sự Cố

### Vấn Đề: "No devices found" hoặc "No iOS devices connected"

**Giải Pháp:**
```bash
# Kiểm tra thiết bị đã kết nối
flutter devices

# Bật Chế Độ Nhà Phát Triển trên thiết bị iOS
# Settings → Privacy & Security → Developer Mode → Enable

# Tin tưởng máy tính trên thiết bị
# Khi được nhắc, nhấn "Trust" trên thiết bị
```

### Vấn Đề: Lỗi Ký Mã

**Lỗi:**
```
Code signing is required for product type 'Application'
```

**Giải Pháp:**
1. Mở Xcode → Dự án Runner
2. Chọn target Runner → Signing & Capabilities
3. Chọn "Automatically manage signing"
4. Chọn Team của bạn
5. Nếu lỗi vẫn còn, dọn dẹp thư mục build:
   ```bash
   cd ios
   rm -rf build Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

### Vấn Đề: "Archive" Bị Vô Hiệu Trong Xcode

**Giải Pháp:**
- Chọn "Generic iOS Device" hoặc "Any iOS Device" làm đích
- Không chọn trình giả lập
- Đảm bảo cấu hình "Release" được chọn
- Kiểm tra ký mã được cấu hình đúng

### Vấn Đề: Lỗi Cài Đặt CocoaPods

**Lỗi:**
```
[!] CocoaPods could not find compatible versions
```

**Giải Pháp:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..
```

### Vấn Đề: Build Thất Bại Với "Undefined symbol"

**Giải Pháp:**
```bash
# Dọn dẹp và xây dựng lại
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter pub get
flutter build ios --release
```

### Vấn Đề: Ứng Dụng Bị Từ Chối Bởi App Store Review

**Lý Do Thường Gặp:**
- Thiếu chính sách quyền riêng tư
- Thông tin ứng dụng không đầy đủ
- Ứng dụng bị sự cố trong quá trình xem xét
- Vi phạm hướng dẫn App Store
- Thiếu mô tả quyền yêu cầu

**Giải Pháp:**
- Xem lại lý do từ chối trong App Store Connect
- Giải quyết tất cả vấn đề được đề cập
- Gửi lại với build hoặc thông tin đã cập nhật

### Vấn Đề: Build TestFlight Không Xuất Hiện

**Giải Pháp:**
- Đợi 10-30 phút để xử lý
- Kiểm tra trạng thái build trong App Store Connect → TestFlight
- Xác minh build được tải lên thành công
- Kiểm tra lỗi xử lý trong App Store Connect

## 📊 Tùy Chọn Cấu Hình Build

### Xây Dựng Cho Phát Triển

```bash
# Build debug (cho phát triển)
flutter build ios --debug

# Build profile (cho kiểm thử hiệu suất)
flutter build ios --profile
```

### Xây Dựng Cho Phân Phối

```bash
# Build release (cho App Store)
flutter build ios --release

# Build release không ký mã (ký trong Xcode)
flutter build ios --release --no-codesign
```

### Xây Dựng Với Cấu Hình Cụ Thể

```bash
# Xây dựng với tên build và số tùy chỉnh
flutter build ios --release \
  --build-name=1.0.0 \
  --build-number=1

# Xây dựng với biến môi trường
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

## 🔄 Cập Nhật Ứng Dụng

### Bước 1: Cập Nhật Phiên Bản

**Tệp:** `pubspec.yaml`

```yaml
version: 1.0.1+2  # Tăng phiên bản và số build
```

### Bước 2: Xây Dựng và Archive

Làm theo quy trình xây dựng và archive giống như gửi ban đầu.

### Bước 3: Tải Lên Build Mới

1. Tải lên build mới lên App Store Connect
2. Chọn build mới trong tab App Store
3. Cập nhật phần "What's New" với ghi chú phát hành
4. Gửi để xem xét

## 📱 Phương Thức Phân Phối

### 1. App Store (Phân Phối Công Khai)

- Có sẵn cho tất cả người dùng
- Yêu cầu xem xét App Store
- Tốt nhất cho bản phát hành sản xuất

### 2. TestFlight (Kiểm Thử Beta)

- Kiểm thử nội bộ: Tối đa 100 người kiểm thử (ngay lập tức)
- Kiểm thử bên ngoài: Tối đa 10,000 người kiểm thử (yêu cầu xem xét)
- Tốt cho kiểm thử beta trước khi phát hành công khai

### 3. Phân Phối Ad Hoc

- Giới hạn 100 thiết bị
- Yêu cầu UDID thiết bị
- Tốt cho kiểm thử nội bộ không có TestFlight

### 4. Phân Phối Doanh Nghiệp

- Yêu cầu Chương Trình Apple Enterprise ($299/năm)
- Phân phối nội bộ không giới hạn
- Cho tổ chức có 100+ nhân viên

## 🔒 Xem Xét Bảo Mật

### Bảo Mật API

- Sử dụng HTTPS cho tất cả lời gọi API
- Xác thực chứng chỉ SSL
- Không hardcode API key hoặc bí mật
- Sử dụng lưu trữ an toàn cho dữ liệu nhạy cảm

### Làm Rối Mã (Tùy Chọn)

```bash
# Xây dựng với làm rối mã
flutter build ios --release --obfuscate --split-debug-info=./debug-info
```

### App Transport Security

- Thực thi kết nối HTTPS
- Cấu hình ngoại lệ ATS chỉ khi cần thiết
- Tài liệu hóa mọi ngoại lệ HTTP

## 📈 Giám Sát và Phân Tích

### Phân Tích App Store Connect

- Theo dõi lượt tải xuống, doanh số và sử dụng
- Giám sát báo cáo sự cố
- Xem đánh giá và xếp hạng người dùng
- Phân tích tương tác người dùng

### Báo Cáo Sự Cố

Cân nhắc tích hợp:
- Firebase Crashlytics
- Sentry
- Báo cáo sự cố tích hợp sẵn của Apple

## ⚠️ Lưu Ý Quan Trọng

1. **Thời Gian Build**: Build iOS có thể mất 5-15 phút tùy thuộc vào kích thước dự án
2. **Thời Gian Xem Xét**: Xem xét App Store thường mất 24-48 giờ
3. **Yêu Cầu Phiên Bản**: Mỗi lần gửi App Store yêu cầu số build mới
4. **Hết Hạn Chứng Chỉ**: Chứng chỉ phân phối hết hạn sau 1 năm, gia hạn trước khi hết hạn
5. **Yêu Cầu Thiết Bị**: Kiểm thử trên nhiều phiên bản iOS và kích thước thiết bị
6. **Bảo Mật Mạng**: Đảm bảo tất cả yêu cầu mạng sử dụng HTTPS trong sản xuất
7. **Quyền Riêng Tư**: Hoàn tất bảng câu hỏi quyền riêng tư chính xác
8. **Hướng Dẫn Nội Dung**: Đảm bảo ứng dụng tuân thủ Hướng Dẫn Xem Xét App Store

## 📚 Tài Nguyên Bổ Sung

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Tài Liệu Apple Developer](https://developer.apple.com/documentation/)
- [Hướng Dẫn Xem Xét App Store](https://developer.apple.com/app-store/review/guidelines/)
- [Trợ Giúp App Store Connect](https://help.apple.com/app-store-connect/)
- [Tài Liệu Xcode](https://developer.apple.com/documentation/xcode)

## 🆘 Nhận Trợ Giúp

Nếu bạn gặp vấn đề:

1. Kiểm tra tài liệu Flutter: `flutter doctor -v`
2. Xem lại nhật ký build Xcode
3. Kiểm tra App Store Connect để tìm lỗi xử lý
4. Xem lại Diễn Đàn Apple Developer
5. Liên hệ Hỗ Trợ Apple Developer (nếu đã đăng ký chương trình)

---

**Cập Nhật Lần Cuối:** 2025
**Được Duy Trì Bởi:** NguyenCaoAnh

