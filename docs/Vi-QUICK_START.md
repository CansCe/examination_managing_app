# Hướng Dẫn Bắt Đầu Nhanh

Hướng dẫn này sẽ giúp bạn thiết lập và chạy Ứng Dụng Quản Lý Thi nhanh chóng cho phát triển cục bộ.

## Yêu Cầu

Trước khi bắt đầu, đảm bảo bạn đã cài đặt những thứ sau:

- **Flutter SDK**: 3.2.3 trở lên ([Cài đặt Flutter](https://flutter.dev/docs/get-started/install))
- **Node.js**: 18.0.0 trở lên ([Tải Node.js](https://nodejs.org/))
- **MongoDB**: Tài khoản MongoDB Atlas (có gói miễn phí) hoặc phiên bản MongoDB cục bộ
- **Git**: Để clone repository

### Xác Minh Cài Đặt

```bash
# Kiểm tra Flutter
flutter --version

# Kiểm tra Node.js
node --version
npm --version

# Kiểm tra Git
git --version
```

## Bước 1: Clone và Thiết Lập

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd exam_management_app
   ```

2. **Lấy phụ thuộc Flutter**
   ```bash
   flutter pub get
   ```

## Bước 2: Cấu Hình MongoDB

### Tùy Chọn A: MongoDB Atlas (Được Khuyến Nghị Cho Người Mới Bắt Đầu)

1. Tạo tài khoản miễn phí tại [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Tạo cluster mới (gói miễn phí M0)
3. Tạo người dùng cơ sở dữ liệu (tên người dùng và mật khẩu)
4. Thêm địa chỉ IP của bạn vào danh sách trắng (hoặc sử dụng `0.0.0.0/0` cho phát triển)
5. Lấy chuỗi kết nối của bạn:
   - Nhấp "Connect" → "Connect your application"
   - Sao chép chuỗi kết nối
   - Thay thế `<password>` bằng mật khẩu người dùng cơ sở dữ liệu của bạn
   - Ví dụ: `mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority`

### Tùy Chọn B: MongoDB Cục Bộ

1. Cài đặt MongoDB cục bộ ([Hướng Dẫn Cài Đặt](https://docs.mongodb.com/manual/installation/))
2. Khởi động dịch vụ MongoDB
3. Chuỗi kết nối: `mongodb://localhost:27017/exam_management`

## Bước 3: Cấu Hình Dịch Vụ Backend

### Dịch Vụ Backend API

1. **Điều hướng đến thư mục backend-api**
   ```bash
   cd backend-api
   ```

2. **Cài đặt phụ thuộc**
   ```bash
   npm install
   ```

3. **Tạo tệp môi trường**
   ```bash
   # Windows
   copy ENV_EXAMPLE.txt .env
   
   # Linux/Mac
   cp ENV_EXAMPLE.txt .env
   ```

4. **Chỉnh sửa tệp `.env`**
   ```env
   MONGODB_URI=your_mongodb_connection_string_here
   MONGODB_DB=exam_management
   PORT=3000
   NODE_ENV=development
   ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
   ```

5. **Khởi động dịch vụ**
   ```bash
   npm start
   ```

   Bạn sẽ thấy:
   ```
   ╔══════════════════════════════════════════════════════════╗
   ║     MAIN API SERVICE - Starting...                       ║
   ╚══════════════════════════════════════════════════════════╝
   
   ✅ MongoDB connected successfully
   ✅ Server running on port 3000
   ```

### Dịch Vụ Chat

1. **Điều hướng đến thư mục backend-chat** (từ thư mục gốc dự án)
   ```bash
   cd backend-chat
   ```

2. **Cài đặt phụ thuộc**
   ```bash
   npm install
   ```

3. **Tạo tệp môi trường**
   ```bash
   # Windows
   copy ENV_EXAMPLE.txt .env
   
   # Linux/Mac
   cp ENV_EXAMPLE.txt .env
   ```

4. **Chỉnh sửa tệp `.env`** (sử dụng cùng MongoDB URI như backend-api)
   ```env
   MONGODB_URI=your_mongodb_connection_string_here
   MONGODB_DB=exam_management
   PORT=3001
   NODE_ENV=development
   ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,http://localhost:3001
   DEFAULT_ADMIN_ID=  # Tùy chọn: MongoDB ObjectId của quản trị viên mặc định
   ```

5. **Khởi động dịch vụ**
   ```bash
   npm start
   ```

   Bạn sẽ thấy:
   ```
   ╔══════════════════════════════════════════════════════════╗
   ║     CHAT SERVICE - Starting...                           ║
   ╚══════════════════════════════════════════════════════════╝
   
   ✅ MongoDB connected successfully
   ✅ Socket.io server initialized
   ✅ Server running on port 3001
   ```

## Bước 4: Chạy Ứng Dụng Flutter

1. **Quay lại thư mục gốc dự án**
   ```bash
   cd ..
   ```

2. **Chạy ứng dụng**
   ```bash
   flutter run
   ```

   Ứng dụng sẽ:
   - Tự động khám phá các endpoint API có sẵn
   - Thử localhost trước, sau đó là các domain sản xuất
   - Lưu endpoint hoạt động để sử dụng trong tương lai

### Cho Trình Giả Lập Android

Nếu chạy trên trình giả lập Android, ứng dụng sẽ tự động thử `http://10.0.2.2:3000` và `http://10.0.2.2:3001` ánh xạ tới localhost của máy chủ của bạn.

## Bước 5: Tạo Dữ Liệu Mẫu (Tùy Chọn)

Để điền dữ liệu mẫu vào cơ sở dữ liệu:

1. **Chạy trình tạo dữ liệu mẫu**
   ```bash
   # Windows
   scripts\generate_mock_data_standalone.bat
   
   # Linux/Mac (nếu có)
   flutter pub run lib/scripts/generate_mock_data_standalone.dart
   ```

   Điều này sẽ:
   - Tạo sinh viên, giáo viên, câu hỏi và kỳ thi mẫu
   - Tải dữ liệu lên MongoDB Atlas
   - Gán kỳ thi cho sinh viên
   - Tạo ID sinh viên theo định dạng: 20210001, 20210002, v.v.

## Bước 6: Xác Minh Mọi Thứ Hoạt Động

1. **Kiểm tra dịch vụ backend đang chạy**
   ```bash
   # Kiểm tra dịch vụ API
   curl http://localhost:3000/health
   
   # Kiểm tra dịch vụ Chat
   curl http://localhost:3001/health
   ```

2. **Khởi chạy ứng dụng Flutter**
   - Ứng dụng sẽ tự động kết nối với backend
   - Kiểm tra bảng điều khiển để xem nhật ký khám phá API
   - Đăng nhập bằng tài khoản thử nghiệm (nếu đã tạo dữ liệu mẫu)

## Khắc Phục Sự Cố

### Dịch Vụ Backend Không Khởi Động

- **Kiểm tra kết nối MongoDB**: Xác minh `MONGODB_URI` của bạn trong tệp `.env`
- **Kiểm tra cổng**: Đảm bảo cổng 3000 và 3001 không được sử dụng
- **Kiểm tra phiên bản Node.js**: Yêu cầu Node.js 18.0.0 trở lên
- **Kiểm tra tệp .env**: Đảm bảo tệp `.env` tồn tại và có định dạng đúng

### Ứng Dụng Flutter Không Thể Kết Nối

- **Kiểm tra dịch vụ backend**: Đảm bảo cả hai dịch vụ đang chạy
- **Kiểm tra nhật ký khám phá API**: Tìm các lần thử kết nối trong bảng điều khiển
- **Đối với trình giả lập Android**: Sử dụng `10.0.2.2` thay vì `localhost` (được xử lý tự động)
- **Kiểm tra CORS**: Đảm bảo `ALLOWED_ORIGINS` bao gồm nguồn client của bạn

### Chat Không Hoạt Động

- **Xác minh kết nối Socket.io**: Kiểm tra bảng điều khiển trình duyệt/Flutter để tìm lỗi WebSocket
- **Kiểm tra dịch vụ chat**: Đảm bảo backend-chat đang chạy trên cổng 3001
- **Kiểm tra CORS**: Đảm bảo dịch vụ chat cho phép nguồn của bạn

## Bước Tiếp Theo

- Đọc [BACKEND_SETUP.md](BACKEND_SETUP.md) để biết cấu hình backend chi tiết
- Đọc [AUTO_DISCOVERY_SETUP.md](AUTO_DISCOVERY_SETUP.md) để biết cấu hình tự động khám phá API
- Đọc [DEPLOYMENT.md](DEPLOYMENT.md) để biết hướng dẫn triển khai sản xuất
- Đọc [CHAT_IMPLEMENTATION.md](CHAT_IMPLEMENTATION.md) để biết chi tiết dịch vụ chat

## Mẹo Phát Triển

- **Hot Reload**: Sử dụng `r` trong terminal Flutter để hot reload
- **Khởi Động Lại Backend**: Khởi động lại dịch vụ backend sau khi thay đổi tệp `.env`
- **Kiểm Tra Nhật Ký**: Cả hai dịch vụ backend xuất nhật ký chi tiết để gỡ lỗi
- **Truy Cập Cơ Sở Dữ Liệu**: Sử dụng MongoDB Compass hoặc giao diện web Atlas để xem dữ liệu

---

