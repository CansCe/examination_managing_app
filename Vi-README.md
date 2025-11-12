# Ứng Dụng Quản Lý Thi

Ứng dụng quản lý thi toàn diện được xây dựng bằng Flutter (frontend) và Node.js/Express (backend), có tính năng kiểm soát truy cập dựa trên vai trò, chat thời gian thực và tích hợp cơ sở dữ liệu MongoDB.

## 🎯 Function

### Chức Năng Cốt Lõi
- **Hệ Thống Đa Vai Trò**: Vai trò Sinh viên, Giáo viên và Quản trị viên với quyền hạn riêng biệt
- **Quản Lý Kỳ Thi**: Tạo, chỉnh sửa, xóa và gán kỳ thi cho sinh viên
- **Ngân Hàng Câu Hỏi**: Quản lý ngân hàng câu hỏi tập trung với nhiều loại câu hỏi
- **Làm Bài Thi**: Sinh viên có thể làm bài thi với bộ đếm thời gian, tự động nộp bài và theo dõi câu trả lời
- **Theo Dõi Kết Quả**: Xem và quản lý kết quả thi với phân tích chi tiết
- **Chat Thời Gian Thực**: Hệ thống chat dựa trên WebSocket để giao tiếp giữa sinh viên và giáo viên

### Trải Nghiệm Người Dùng
- **Tự Động Khám Phá API**: Ứng dụng tự động tìm và kết nối với các dịch vụ backend có sẵn
- **Cuộn Ngang**: Các kỳ thi sắp tới được hiển thị trong danh sách ngang có thể kéo, hiệu ứng mờ
- **Thiết Kế Phản Hồi**: Tối ưu hóa cho thiết bị di động với hoạt ảnh mượt mà
- **Hỗ Trợ Offline**: Lưu trữ dữ liệu cục bộ với SharedPreferences

## 🏗️ Kiến Trúc

### Frontend (Flutter)
- **Framework**: Flutter 3.2.3+
- **Ngôn Ngữ**: Dart
- **Quản Lý Trạng Thái**: StatefulWidget với setState
- **Gói Quan Trọng**:
  - `http`: Giao tiếp REST API
  - `socket_io_client`: Kết nối WebSocket cho chat
  - `mongo_dart`: Truy cập MongoDB trực tiếp (để tạo dữ liệu mẫu)
  - `shared_preferences`: Lưu trữ cục bộ cho các endpoint API và tùy chọn người dùng
  - `uuid`: Tạo định danh duy nhất

### Dịch Vụ Backend

#### 1. Dịch Vụ API Chính (`backend-api`)
- **Port**: 3000
- **Công Nghệ**: Node.js + Express
- **Cơ Sở Dữ Liệu**: MongoDB
- **Tính Năng**:
  - REST API cho kỳ thi, sinh viên, giáo viên, câu hỏi và kết quả
  - Endpoint xác thực
  - Làm sạch đầu vào để ngăn chặn NoSQL injection
  - Giới hạn tốc độ trên tất cả các endpoint
  - Cấu hình CORS
  - Endpoint kiểm tra sức khỏe

#### 2. Dịch Vụ Chat (`backend-chat`)
- **Port**: 3001
- **Công Nghệ**: Node.js + Express + Socket.io
- **Cơ Sở Dữ Liệu**: MongoDB
- **Tính Năng**:
  - Nhắn tin thời gian thực qua WebSocket
  - Lưu trữ tin nhắn trong MongoDB
  - Chat dựa trên phòng (cuộc trò chuyện một-một)
  - Tự động dọn dẹp tin nhắn cũ hơn 30 ngày
  - Hỗ trợ sinh viên và giáo viên chat với quản trị viên

### Cơ Sở Dữ Liệu
- **MongoDB**: Cơ sở dữ liệu chính (MongoDB Atlas hoặc tự lưu trữ)
- **Bộ Sưu Tập**:
  - `exams`: Định nghĩa kỳ thi
  - `students`: Hồ sơ sinh viên
  - `teachers`: Hồ sơ giáo viên
  - `questions`: Ngân hàng câu hỏi
  - `student_exams`: Gán kỳ thi
  - `exam_results`: Nộp bài và kết quả thi
  - `messages`: Tin nhắn chat
  - `conversations`: Siêu dữ liệu cuộc trò chuyện chat

## 📁 Cấu Trúc Dự Án

```
exam_management_app/
├── lib/                          # Mã nguồn ứng dụng Flutter
│   ├── config/                   # Tệp cấu hình
│   │   ├── api_config.dart      # Cấu hình endpoint API
│   │   ├── database_config.dart # Cấu hình kết nối cơ sở dữ liệu
│   │   └── routes.dart          # Cấu hình định tuyến ứng dụng
│   ├── features/                 # Tính năng ứng dụng (trang, widget)
│   │   ├── admin/               # Trang dành riêng cho quản trị viên
│   │   ├── exams/               # Trang quản lý kỳ thi
│   │   ├── questions/           # Trang ngân hàng câu hỏi
│   │   ├── shared/              # Thành phần dùng chung
│   │   ├── home_page.dart       # Màn hình chính
│   │   ├── login_page.dart      # Trang xác thực
│   │   ├── exam_details_page.dart
│   │   └── examination_page.dart
│   ├── models/                  # Mô hình dữ liệu
│   │   ├── exam.dart
│   │   ├── student.dart
│   │   ├── teacher.dart
│   │   ├── question.dart
│   │   └── user_role.dart
│   ├── services/                # Lớp API và dịch vụ
│   │   ├── api_service.dart     # Client REST API
│   │   ├── atlas_service.dart   # Dịch vụ MongoDB Atlas
│   │   ├── chat_service.dart    # Client chat WebSocket
│   │   ├── auth_service.dart    # Dịch vụ xác thực
│   │   ├── api_discovery_service.dart # Dịch vụ tự động khám phá
│   │   ├── api_cache_service.dart # Bộ nhớ đệm phản hồi API
│   │   └── mongodb_service.dart # Truy cập MongoDB trực tiếp
│   ├── utils/                   # Hàm tiện ích
│   └── main.dart                # Điểm vào ứng dụng
├── backend-api/                  # Dịch vụ API chính
│   ├── controllers/             # Xử lý yêu cầu
│   ├── routes/                  # Tuyến API
│   ├── middleware/              # Middleware Express
│   │   ├── rateLimiter.js      # Giới hạn tốc độ
│   │   └── errorHandler.js     # Xử lý lỗi
│   ├── utils/                   # Hàm tiện ích
│   │   └── inputSanitizer.js   # Làm sạch đầu vào
│   ├── config/                  # Cấu hình
│   │   └── database.js          # Kết nối MongoDB
│   ├── server.js                # Máy chủ Express
│   ├── package.json
│   ├── Dockerfile               # Cấu hình hình ảnh Docker
│   └── ENV_EXAMPLE.txt          # Mẫu biến môi trường
├── backend-chat/                 # Dịch vụ chat
│   ├── controllers/             # Bộ điều khiển chat
│   ├── routes/                  # Tuyến chat
│   ├── sockets/                  # Xử lý Socket.io
│   ├── scripts/                 # Script tiện ích
│   │   └── cleanup-old-messages.js
│   ├── config/                  # Cấu hình
│   │   ├── database.js          # Kết nối MongoDB
│   │   └── socket.js            # Thiết lập Socket.io
│   ├── server.js                # Máy chủ Express + Socket.io
│   ├── package.json
│   ├── Dockerfile               # Cấu hình hình ảnh Docker
│   └── ENV_EXAMPLE.txt
├── nginx/                        # Tệp cấu hình Nginx
│   ├── exam-app-api.duckdns.org.conf  # Cấu hình dịch vụ API
│   ├── backend-chat.duckdns.org.conf  # Cấu hình dịch vụ chat
│   └── nginx.conf.fix           # Sửa lỗi cấu hình Nginx chính
├── scripts/                      # Script tiện ích
│   └── generate_mock_data_standalone.bat
├── docs/                         # Tài liệu
│   ├── HTTPS_UPGRADE.md         # Hướng dẫn nâng cấp HTTP lên HTTPS
│   ├── API_PERFORMANCE_OPTIMIZATION.md
│   ├── DEPLOYMENT.md
│   └── ... (tài liệu khác)
├── docker-compose.yml            # Cấu hình Docker Compose
└── pubspec.yaml                  # Flutter Dependance
```

## 🚀 Bắt Đầu Nhanh

### Yêu Cầu
- **Flutter SDK**: 3.2.3 trở lên
- **Node.js**: 18.0.0 trở lên
- **MongoDB**: Tài khoản MongoDB Atlas hoặc phiên bản MongoDB cục bộ
- **Docker** (tùy chọn): Để triển khai container hóa

### Thiết Lập Phát Triển Cục Bộ

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd exam_management_app
   ```

2. **Thiết lập Backend API**
   ```bash
   cd backend-api
   npm install
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env và thêm MONGODB_URI của bạn
   npm start
   ```

3. **Thiết lập Dịch Vụ Chat**
   ```bash
   cd backend-chat
   npm install
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env và thêm MONGODB_URI của bạn (giống như backend-api)
   npm start
   ```

4. **Thiết lập Ứng Dụng Flutter**
   ```bash
   flutter pub get
   flutter run
   ```

### Thiết Lập Docker (Được Khuyến Nghị)

1. **Cấu hình biến môi trường**
   ```bash
   # Backend API
   cd backend-api
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env với MongoDB URI của bạn
   
   # Dịch Vụ Chat
   cd backend-chat
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env với MongoDB URI của bạn
   ```

2. **Khởi động dịch vụ**
   ```bash
   docker-compose up -d
   ```

3. **Xác minh dịch vụ đang chạy**
   ```bash
   curl http://localhost:3000/health  # Dịch vụ API
   curl http://localhost:3001/health  # Dịch vụ chat
   ```

## 📱 Cấu Hình Ứng Dụng Di Động

### Tự Động Khám Phá API (Được Khuyến Nghị)

Ứng dụng tự động khám phá các endpoint API có sẵn khi khởi chạy lần đầu:
- Thử nhiều domain tiềm năng (localhost, domain sản xuất)
- Sử dụng domain đầu tiên phản hồi
- Lưu trữ cục bộ để sử dụng trong tương lai
- Xác thực lại khi khởi chạy

**Để thêm domain của bạn:**
1. Chỉnh sửa `lib/services/api_discovery_service.dart`
2. Thêm URL domain của bạn vào danh sách `_defaultApiUrls` và `_defaultChatUrls`
3. Xây dựng ứng dụng bình thường (không cần cờ đặc biệt)

Xem [docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md) để biết hướng dẫn chi tiết.

### Cấu Hình Thủ Công (Tùy Chọn)

**Cấu hình khi xây dựng:**
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=CHAT_BASE_URL=https://chat.yourdomain.com
```

**Cấu hình thời gian chạy:**
- Cài đặt ứng dụng cho phép cấu hình endpoint API thủ công
- Quay lại localhost để phát triển

## 🔒 Tính Năng Bảo Mật

### Bảo Mật Backend
- **Làm Sạch Đầu Vào**: Tất cả đầu vào người dùng được làm sạch để ngăn chặn NoSQL injection
- **Giới Hạn Tốc Độ**: Các endpoint API được bảo vệ bằng giới hạn tốc độ:
  - Endpoint xác thực: 5 yêu cầu mỗi 15 phút
  - Thao tác đọc: 100 yêu cầu mỗi 15 phút
  - Thao tác ghi: 20 yêu cầu mỗi 15 phút
  - Kiểm tra sức khỏe: 200 yêu cầu mỗi 15 phút
- **CORS**: Được cấu hình để chỉ cho phép các nguồn được chỉ định
- **Helmet**: Middleware tiêu đề bảo mật
- **Biến Môi Trường**: Dữ liệu nhạy cảm (MongoDB URI) được lưu trong tệp `.env`, không phải trong mã
- **HTTPS/SSL**: Hỗ trợ HTTPS với chứng chỉ SSL Let's Encrypt (xem [HTTPS_UPGRADE.md](docs/HTTPS_UPGRADE.md))

### Bảo Mật Frontend
- **Khám Phá API**: Xác thực endpoint trước khi kết nối
- **Xử Lý Lỗi**: Xử lý lỗi lịch sự cho lỗi mạng
- **Xác Thực Đầu Vào**: Xác thực phía client trước khi gọi API

## 🗄️ Lược Đồ Cơ Sở Dữ Liệu

### Bộ Sưu Tập Exams
```javascript
{
  _id: ObjectId,
  title: String,
  description: String,
  subject: String,
  difficulty: String,
  examDate: Date,
  examTime: String,
  duration: Number, // phút
  maxStudents: Number,
  questions: [ObjectId], // Tham chiếu đến bộ sưu tập questions
  createdBy: ObjectId, // ID Giáo viên/Quản trị viên
  createdAt: Date,
  updatedAt: Date,
  status: String,
  isDummy: Boolean // Cờ để xác định kỳ thi mẫu
}
```

### Bộ Sưu Tập Students
```javascript
{
  _id: ObjectId,
  studentId: String, // Định dạng: 20210001, 20210002, v.v.
  rollNumber: String,
  name: String,
  email: String,
  className: String,
  assignedExams: [ObjectId], // ID kỳ thi
  createdAt: Date,
  updatedAt: Date
}
```

### Bộ Sưu Tập Questions
```javascript
{
  _id: ObjectId,
  questionText: String,
  type: String, // 'multiple_choice', 'true_false', 'short_answer'
  options: [String], // Cho câu hỏi trắc nghiệm
  correctAnswer: String,
  points: Number,
  subject: String,
  difficulty: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Bộ Sưu Tập Messages
```javascript
{
  _id: ObjectId,
  conversationId: String,
  senderId: ObjectId,
  receiverId: ObjectId,
  message: String,
  timestamp: Date,
  read: Boolean,
  createdAt: Date
}
```

## 📚 Tài Liệu

### Bắt Đầu
- **[docs/QUICK_START.md](docs/QUICK_START.md)** - Hướng dẫn thiết lập nhanh cho phát triển cục bộ
- **[docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md)** - Hướng dẫn thiết lập backend chi tiết
- **[docs/AUTO_DISCOVERY_SETUP.md](docs/AUTO_DISCOVERY_SETUP.md)** - Cấu hình tự động khám phá API

### Triển Khai
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Hướng dẫn triển khai hoàn chỉnh
- **[docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)** - Hướng dẫn triển khai Docker
- **[docs/PRODUCTION_DEPLOYMENT.md](docs/PRODUCTION_DEPLOYMENT.md)** - Triển khai máy chủ sản xuất
- **[docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md](docs/SERVER_DEPLOYMENT_WITH_DOMAINS.md)** - Triển khai với tên miền
- **[docs/HTTPS_UPGRADE.md](docs/HTTPS_UPGRADE.md)** - Nâng cấp Nginx từ HTTP lên HTTPS với chứng chỉ SSL

### Tính Năng
- **[docs/CHAT_IMPLEMENTATION.md](docs/CHAT_IMPLEMENTATION.md)** - Tài liệu dịch vụ chat
- **[docs/CHAT_SERVICE_USAGE.md](docs/CHAT_SERVICE_USAGE.md)** - Cách sử dụng dịch vụ chat

### Triển Khai Theo Nền Tảng
- **[docs/IOS_DEPLOYMENT.md](docs/IOS_DEPLOYMENT.md)** - Hướng dẫn hoàn chỉnh để triển khai lên iOS App Store

### Tài Liệu Tiếng Việt
- **[Vi-README.md](Vi-README.md)** - README tiếng Việt
- **[docs/Vi-QUICK_START.md](docs/Vi-QUICK_START.md)** - Hướng dẫn bắt đầu nhanh tiếng Việt
- **[docs/Vi-HTTPS_UPGRADE.md](docs/Vi-HTTPS_UPGRADE.md)** - Hướng dẫn nâng cấp HTTPS tiếng Việt
- **[docs/Vi-DEPLOYMENT.md](docs/Vi-DEPLOYMENT.md)** - Hướng dẫn triển khai tiếng Việt
- **[docs/Vi-IOS_DEPLOYMENT.md](docs/Vi-IOS_DEPLOYMENT.md)** - Hướng dẫn triển khai iOS tiếng Việt

## 🛠️ Build

### Chạy Kiểm Tra
```bash
flutter test
```

### Xây Dựng Cho Sản Xuất

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

### Tạo Dữ Liệu Mẫu
```bash
# Windows
scripts\generate_mock_data_standalone.bat

# Script sẽ:
# 1. Tạo sinh viên, giáo viên, câu hỏi và kỳ thi mẫu
# 2. Tải dữ liệu lên MongoDB Atlas
# 3. Gán kỳ thi cho sinh viên
```

## 🔧 Cấu Hình

### Biến Môi Trường

#### Backend API (`backend-api/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

#### Dịch Vụ Chat (`backend-chat/.env`)
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=development
ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

## 🐛 Khắc Phục Sự Cố

### Dịch Vụ Backend Không Khởi Động
- Kiểm tra chuỗi kết nối MongoDB trong tệp `.env`
- Xác minh cổng 3000 và 3001 không được sử dụng
- Kiểm tra phiên bản Node.js (yêu cầu 18.0.0+)

### Ứng Dụng Di Động Không Thể Kết Nối
- Xác minh dịch vụ backend đang chạy
- Kiểm tra nhật ký dịch vụ khám phá API
- Đảm bảo CORS được cấu hình đúng
- Đối với trình giả lập Android, sử dụng `10.0.2.2` thay vì `localhost`
- Nếu sử dụng HTTPS, xác minh chứng chỉ SSL hợp lệ và chưa hết hạn

### Chat Không Hoạt Động
- Xác minh kết nối Socket.io trong bảng điều khiển trình duyệt
- Kiểm tra hỗ trợ WebSocket trong cấu hình mạng
- Đảm bảo dịch vụ chat đang chạy trên cổng 3001

## 📝 Giấy Phép

Dự án này là riêng tư và không được cấp phép để sử dụng công khai.

## 🤝 Đóng Góp

Đây là một dự án công khai. Đối với các đóng góp nội bộ, vui lòng tuân theo phong cách mã hiện có và gửi pull request để xem xét.

## 📞 Hỗ Trợ

Đối với vấn đề hoặc câu hỏi:
1. Kiểm tra tài liệu trong thư mục `docs/`
2. Xem lại nhật ký lỗi trong dịch vụ backend
3. Kiểm tra bảng điều khiển ứng dụng Flutter để biết nhật ký khám phá API

---

