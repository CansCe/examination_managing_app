# Hướng Dẫn Triển Khai

Hướng dẫn này bao gồm việc triển khai Ứng Dụng Quản Lý Thi lên sản xuất, bao gồm cả dịch vụ backend và ứng dụng di động Flutter.

## Tổng Quan Triển Khai

Ứng dụng bao gồm:
- **Dịch Vụ Backend API**: REST API (cổng 3000)
- **Dịch Vụ Chat**: Chat WebSocket (cổng 3001)
- **Ứng Dụng Di Động Flutter**: Ứng dụng iOS và Android
- **Cơ Sở Dữ Liệu MongoDB**: MongoDB Atlas hoặc tự lưu trữ

## Điều Kiện Tiên Quyết

- Máy chủ có Node.js 18.0.0+ đã cài đặt
- Tên miền (tùy chọn nhưng được khuyến nghị)
- Tài khoản MongoDB Atlas hoặc phiên bản MongoDB
- Chứng chỉ SSL (cho HTTPS)
- Reverse proxy (Nginx được khuyến nghị)

## Tùy Chọn Triển Khai

### Tùy Chọn 1: Triển Khai Docker (Được Khuyến Nghị)

Xem [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) để biết thiết lập Docker chi tiết.

### Tùy Chọn 2: Triển Khai Máy Chủ Thủ Công

Xem [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) để biết thiết lập máy chủ thủ công.

### Tùy Chọn 3: Máy Chủ Với Tên Miền

Xem [SERVER_DEPLOYMENT_WITH_DOMAINS.md](SERVER_DEPLOYMENT_WITH_DOMAINS.md) để biết thiết lập tên miền.

## Triển Khai Docker Nhanh

1. **Chuẩn bị tệp môi trường**
   ```bash
   # Backend API
   cd backend-api
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env với MongoDB URI của bạn
   
   # Dịch Vụ Chat
   cd ../backend-chat
   cp ENV_EXAMPLE.txt .env
   # Chỉnh sửa .env với MongoDB URI của bạn
   ```

2. **Khởi động dịch vụ với Docker Compose**
   ```bash
   cd ..
   docker-compose up -d
   ```

3. **Xác minh dịch vụ**
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:3001/health
   ```

## Triển Khai Dịch Vụ Backend

### Cấu Hình Môi Trường

Cả hai dịch vụ yêu cầu tệp `.env` với:

**backend-api/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
```

**backend-chat/.env:**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/exam_management?retryWrites=true&w=majority
MONGODB_DB=exam_management
PORT=3001
NODE_ENV=production
ALLOWED_ORIGINS=https://yourdomain.com,https://chat.yourdomain.com
DEFAULT_ADMIN_ID=507f1f77bcf86cd799439011
```

### Sử Dụng PM2 (Trình Quản Lý Tiến Trình)

1. **Cài đặt PM2**
   ```bash
   npm install -g pm2
   ```

2. **Khởi động dịch vụ với PM2**
   ```bash
   # Dịch vụ API
   cd backend-api
   pm2 start server.js --name exam-api
   
   # Dịch vụ Chat
   cd ../backend-chat
   pm2 start server.js --name exam-chat
   ```

3. **Lưu cấu hình PM2**
   ```bash
   pm2 save
   pm2 startup
   ```

4. **Giám sát dịch vụ**
   ```bash
   pm2 status
   pm2 logs
   ```

## Thiết Lập Nginx Reverse Proxy

### Cài Đặt Nginx

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
```

### Cấu Hình Nginx

Tạo `/etc/nginx/sites-available/exam-app`:

```nginx
# Dịch vụ API
server {
    listen 80;
    server_name api.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Dịch vụ Chat
server {
    listen 80;
    server_name chat.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Hỗ trợ WebSocket
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### Bật SSL Với Let's Encrypt

```bash
# Cài đặt Certbot
sudo apt install certbot python3-certbot-nginx

# Lấy chứng chỉ SSL
sudo certbot --nginx -d api.yourdomain.com
sudo certbot --nginx -d chat.yourdomain.com
```

### Bật Trang Web

```bash
sudo ln -s /etc/nginx/sites-available/exam-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Triển Khai Ứng Dụng Flutter

### Xây Dựng Cho Sản Xuất

**Android:**
```bash
flutter build apk --release
# hoặc cho app bundle
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

### Cập Nhật Khám Phá API

Trước khi xây dựng, cập nhật `lib/services/api_discovery_service.dart` với domain sản xuất của bạn:

```dart
static final List<String> _defaultApiUrls = [
  'https://api.yourdomain.com',
  'http://api.yourdomain.com',
];

static final List<String> _defaultChatUrls = [
  'https://chat.yourdomain.com',
  'http://chat.yourdomain.com',
];
```

### Xuất Bản Lên Cửa Hàng Ứng Dụng

**Android (Google Play):**
1. Xây dựng app bundle: `flutter build appbundle --release`
2. Tải lên Google Play Console
3. Hoàn tất danh sách cửa hàng và gửi để xem xét

**iOS (App Store):**
1. Xây dựng ứng dụng iOS: `flutter build ios --release`
2. Lưu trữ trong Xcode
3. Tải lên App Store Connect
4. Gửi để xem xét

## Danh Sách Kiểm Tra Bảo Mật

- [ ] Sử dụng HTTPS cho tất cả dịch vụ
- [ ] Cấu hình CORS đúng cách
- [ ] Bật giới hạn tốc độ
- [ ] Sử dụng biến môi trường cho bí mật
- [ ] Giữ phụ thuộc được cập nhật
- [ ] Bật xác thực MongoDB
- [ ] Sử dụng mật khẩu mạnh
- [ ] Cấu hình quy tắc tường lửa
- [ ] Bật chứng chỉ SSL/TLS
- [ ] Thiết lập giám sát và ghi nhật ký

## Giám Sát

### Kiểm Tra Sức Khỏe

Cả hai dịch vụ cung cấp endpoint kiểm tra sức khỏe:
- API: `GET /health`
- Chat: `GET /health`

Thiết lập giám sát để kiểm tra các endpoint này thường xuyên.

### Nhật Ký

- **Nhật ký PM2**: `pm2 logs`
- **Nhật ký Docker**: `docker-compose logs`
- **Nhật ký Nginx**: `/var/log/nginx/access.log` và `/var/log/nginx/error.log`

### Giám Sát Cơ Sở Dữ Liệu

Giám sát bảng điều khiển MongoDB Atlas hoặc thiết lập công cụ giám sát MongoDB.

## Chiến Lược Sao Lưu

1. **Sao Lưu Cơ Sở Dữ Liệu**: Thiết lập sao lưu tự động MongoDB Atlas
2. **Sao Lưu Mã**: Sử dụng repository Git
3. **Sao Lưu Cấu Hình**: Sao lưu tệp `.env` một cách an toàn
4. **Chứng Chỉ SSL**: Sao lưu chứng chỉ SSL

## Khắc Phục Sự Cố

### Dịch Vụ Không Khởi Động

- Kiểm tra kết nối MongoDB
- Xác minh biến môi trường
- Kiểm tra tính khả dụng cổng
- Xem lại nhật ký dịch vụ

### Ứng Dụng Không Thể Kết Nối

- Xác minh dịch vụ backend đang chạy
- Kiểm tra cấu hình CORS
- Xác minh tên miền phân giải đúng
- Kiểm tra quy tắc tường lửa

### Vấn Đề Chứng Chỉ SSL

- Xác minh bản ghi DNS tên miền
- Kiểm tra ngày hết hạn chứng chỉ
- Gia hạn chứng chỉ: `sudo certbot renew`

## Mở Rộng Quy Mô

### Mở Rộng Quy Mô Ngang

- Sử dụng bộ cân bằng tải cho nhiều phiên bản
- Cấu hình bộ sao chép MongoDB
- Sử dụng Redis để lưu trữ phiên (nếu cần)

### Mở Rộng Quy Mô Dọc

- Tăng tài nguyên máy chủ
- Tối ưu hóa truy vấn cơ sở dữ liệu
- Sử dụng bộ nhớ đệm khi thích hợp

## Bảo Trì

### Cập Nhật Thường Xuyên

- Cập nhật phụ thuộc Node.js: `npm update`
- Cập nhật phụ thuộc Flutter: `flutter pub upgrade`
- Giữ driver MongoDB được cập nhật
- Giám sát thông báo bảo mật

### Bảo Trì Cơ Sở Dữ Liệu

- Sao lưu thường xuyên
- Tối ưu hóa chỉ mục
- Dọn dẹp dữ liệu cũ (tin nhắn chat, v.v.)

---

