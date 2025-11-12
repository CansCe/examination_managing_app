# Nâng Cấp Nginx Từ HTTP Lên HTTPS

Hướng dẫn này cung cấp hướng dẫn từng bước để nâng cấp cấu hình reverse proxy Nginx của bạn từ HTTP lên HTTPS bằng chứng chỉ SSL Let's Encrypt.

## 📋 Điều Kiện Tiên Quyết

### Điều Kiện Bắt Buộc

Trước khi nâng cấp lên HTTPS, đảm bảo các điều kiện sau được đáp ứng:

1. **Tên Miền Đã Được Cấu Hình**
   - ✅ Tên miền phải trỏ đến địa chỉ IP công cộng của máy chủ của bạn
   - ✅ Bản ghi DNS phải được cấu hình đúng (bản ghi A cho IPv4)
   - ✅ Tên miền phải có thể truy cập từ internet (không chỉ localhost)
   - ✅ Đối với DuckDNS: Tên miền phải được đăng ký và cập nhật với IP của bạn

2. **Quyền Truy Cập Máy Chủ**
   - ✅ Quyền root hoặc sudo trên máy chủ
   - ✅ Quyền truy cập SSH vào máy chủ
   - ✅ Nginx đã được cài đặt và đang chạy

3. **Cấu Hình Mạng**
   - ✅ Cổng 80 (HTTP) phải mở và có thể truy cập
   - ✅ Cổng 443 (HTTPS) phải mở và có thể truy cập
   - ✅ Tường lửa được cấu hình để cho phép lưu lượng HTTP/HTTPS

4. **Dịch Vụ Backend**
   - ✅ Dịch vụ backend (API và Chat) phải đang chạy
   - ✅ Dịch vụ có thể truy cập trên localhost:3000 và localhost:3001
   - ✅ Dịch vụ được cấu hình để chấp nhận kết nối từ Nginx

5. **Cấu Hình Nginx**
   - ✅ Tệp cấu hình Nginx tồn tại và hoạt động cho HTTP
   - ✅ Nginx có quyền ghi vào thư mục chứng chỉ
   - ✅ Nginx có thể bind vào cổng 80 và 443

### Tùy Chọn Nhưng Được Khuyến Nghị

- ✅ Địa chỉ email cho thông báo Let's Encrypt
- ✅ Sao lưu cấu hình Nginx hiện tại
- ✅ Thiết lập giám sát/nhật ký cho việc hết hạn chứng chỉ SSL

## 🚀 Quy Trình Nâng Cấp Từng Bước

### Bước 1: Cài Đặt Certbot

Certbot là client Let's Encrypt chính thức để lấy và quản lý chứng chỉ SSL.

```bash
# Cập nhật danh sách gói
sudo apt update

# Cài đặt Certbot và plugin Nginx
sudo apt install certbot python3-certbot-nginx -y

# Xác minh cài đặt
certbot --version
```

**Kết Quả Mong Đợi:**
```
certbot 2.x.x
```

### Bước 2: Sao Lưu Cấu Hình Hiện Tại

**⚠️ QUAN TRỌNG: Luôn sao lưu trước khi thay đổi!**

```bash
# Tạo thư mục sao lưu
sudo mkdir -p /etc/nginx/backup

# Sao lưu cấu hình Nginx hiện tại
sudo cp -r /etc/nginx/sites-available/* /etc/nginx/backup/
sudo cp /etc/nginx/nginx.conf /etc/nginx/backup/nginx.conf.backup

# Xác minh sao lưu
ls -la /etc/nginx/backup/
```

### Bước 3: Xác Minh Khả Năng Truy Cập Tên Miền

Trước khi lấy chứng chỉ, xác minh rằng tên miền của bạn có thể truy cập:

```bash
# Kiểm tra phân giải tên miền
nslookup exam-app-api.duckdns.org
nslookup backend-chat.duckdns.org

# Kiểm tra khả năng truy cập HTTP (nên trả về 200 hoặc 301)
curl -I http://exam-app-api.duckdns.org/health
curl -I http://backend-chat.duckdns.org/health
```

**Kết Quả Mong Đợi:**
- DNS nên phân giải đến IP máy chủ của bạn
- Yêu cầu HTTP nên trả về trạng thái 200 hoặc 301

### Bước 4: Lấy Chứng Chỉ SSL

#### Tùy Chọn A: Cấu Hình Tự Động (Được Khuyến Nghị)

Certbot có thể tự động cấu hình Nginx cho HTTPS:

```bash
# Đối với dịch vụ API
sudo certbot --nginx -d exam-app-api.duckdns.org

# Đối với dịch vụ Chat
sudo certbot --nginx -d backend-chat.duckdns.org
```

**Trong quá trình này, Certbot sẽ:**
1. Yêu cầu địa chỉ email của bạn (cho thông báo gia hạn)
2. Yêu cầu đồng ý với Điều khoản Dịch vụ
3. Hỏi xem bạn có muốn chia sẻ email với EFF không (tùy chọn)
4. Hỏi xem bạn có muốn chuyển hướng HTTP sang HTTPS không (được khuyến nghị: Có)

**Kết Quả Mong Đợi:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

#### Tùy Chọn B: Chỉ Lấy Chứng Chỉ Thủ Công

Nếu bạn muốn cấu hình Nginx thủ công:

```bash
# Chỉ lấy chứng chỉ (không cấu hình Nginx)
sudo certbot certonly --nginx -d exam-app-api.duckdns.org
sudo certbot certonly --nginx -d backend-chat.duckdns.org
```

### Bước 5: Xác Minh Cài Đặt Chứng Chỉ

```bash
# Kiểm tra trạng thái chứng chỉ
sudo certbot certificates

# Kết quả mong đợi hiển thị:
# - Đường dẫn chứng chỉ
# - Ngày hết hạn
# - Tên miền được bao phủ
```

**Kết Quả Mong Đợi:**
```
Found the following certificates:
  Certificate Name: exam-app-api.duckdns.org
    Domains: exam-app-api.duckdns.org
    Expiry Date: YYYY-MM-DD HH:MM:SS+00:00 (VALID: XX days)
    Certificate Path: /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

### Bước 6: Cấu Hình Thủ Công (Nếu Sử Dụng Tùy Chọn B)

Nếu bạn sử dụng Tùy Chọn B, hãy cập nhật tệp cấu hình Nginx của bạn thủ công.

#### Cấu Hình Dịch Vụ API

**Tệp:** `/etc/nginx/sites-available/exam-app-api.duckdns.org`

```nginx
# Chuyển hướng HTTP sang HTTPS
server {
    listen 80;
    server_name exam-app-api.duckdns.org;
    
    # Chuyển hướng tất cả lưu lượng HTTP sang HTTPS
    return 301 https://$server_name$request_uri;
}

# Khối máy chủ HTTPS
server {
    listen 443 ssl http2;
    server_name exam-app-api.duckdns.org;

    # Đường dẫn chứng chỉ SSL
    ssl_certificate /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem;
    
    # Cấu Hình SSL (Cài đặt hiện đại, bảo mật)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Tiêu đề bảo mật
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Ghi nhật ký
    access_log /var/log/nginx/exam-app-api-access.log;
    error_log /var/log/nginx/exam-app-api-error.log;

    # Proxy đến container Docker
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

#### Cấu Hình Dịch Vụ Chat

**Tệp:** `/etc/nginx/sites-available/backend-chat.duckdns.org`

```nginx
# Chuyển hướng HTTP sang HTTPS
server {
    listen 80;
    server_name backend-chat.duckdns.org;
    
    # Chuyển hướng tất cả lưu lượng HTTP sang HTTPS
    return 301 https://$server_name$request_uri;
}

# Khối máy chủ HTTPS
server {
    listen 443 ssl http2;
    server_name backend-chat.duckdns.org;

    # Đường dẫn chứng chỉ SSL
    ssl_certificate /etc/letsencrypt/live/backend-chat.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/backend-chat.duckdns.org/privkey.pem;
    
    # Cấu Hình SSL (Cài đặt hiện đại, bảo mật)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Tiêu đề bảo mật
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Ghi nhật ký
    access_log /var/log/nginx/backend-chat-access.log;
    error_log /var/log/nginx/backend-chat-error.log;

    # Proxy đến container Docker (Hỗ trợ Socket.io)
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # Hỗ trợ WebSocket cho Socket.io
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Cài đặt cụ thể cho Socket.io
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout cho kết nối lâu dài (7 ngày cho Socket.io)
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
    
    # Endpoint Socket.io rõ ràng (tùy chọn, nhưng được khuyến nghị)
    location /socket.io/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
```

### Bước 7: Kiểm Tra Cấu Hình Nginx

```bash
# Kiểm tra cú pháp cấu hình
sudo nginx -t

# Kết quả mong đợi:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**Nếu xảy ra lỗi:**
- Kiểm tra đường dẫn chứng chỉ đúng
- Xác minh quyền tệp
- Kiểm tra lỗi cú pháp trong cấu hình

### Bước 8: Tải Lại Nginx

```bash
# Tải lại Nginx để áp dụng thay đổi
sudo systemctl reload nginx

# Xác minh Nginx đang chạy
sudo systemctl status nginx
```

**Trạng Thái Mong Đợi:**
```
● nginx.service - A high performance web server and a reverse proxy server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: active (running) since ...
```

### Bước 9: Cấu Hình Tường Lửa

```bash
# Cho phép lưu lượng HTTPS (nếu chưa được phép)
sudo ufw allow 443/tcp

# Xác minh quy tắc tường lửa
sudo ufw status
```

**Kết Quả Mong Đợi:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

### Bước 10: Kiểm Tra HTTPS

```bash
# Kiểm tra HTTPS dịch vụ API
curl https://exam-app-api.duckdns.org/health

# Kiểm tra HTTPS dịch vụ Chat
curl https://backend-chat.duckdns.org/health

# Kiểm tra chuyển hướng HTTP sang HTTPS
curl -I http://exam-app-api.duckdns.org/health
# Nên trả về: HTTP/1.1 301 Moved Permanently
```

**Kết Quả Mong Đợi:**
- Yêu cầu HTTPS trả về trạng thái 200
- Yêu cầu HTTP chuyển hướng sang HTTPS (301)
- Chứng chỉ SSL hợp lệ (không có cảnh báo)

### Bước 11: Cấu Hình Tự Động Gia Hạn

Chứng chỉ Let's Encrypt hết hạn sau mỗi 90 ngày. Certbot thiết lập gia hạn tự động:

```bash
# Kiểm tra trạng thái bộ hẹn giờ gia hạn
sudo systemctl status certbot.timer

# Kiểm tra gia hạn (chạy thử)
sudo certbot renew --dry-run

# Kết quả mong đợi:
# The dry run was successful.
```

**Gia Hạn Thủ Công (nếu cần):**
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## 🔧 Cấu Hình Sau Nâng Cấp

### Cập Nhật Cấu Hình Ứng Dụng Flutter

Cập nhật ứng dụng Flutter của bạn để sử dụng URL HTTPS:

**Tệp:** `lib/config/api_config.dart`

```dart
// Thay đổi từ HTTP sang HTTPS
static const String baseUrl = 'https://exam-app-api.duckdns.org';
static const String chatBaseUrl = 'https://backend-chat.duckdns.org';
```

**Tệp:** `lib/services/api_discovery_service.dart`

Cập nhật URL mặc định để sử dụng HTTPS:

```dart
static const List<String> _defaultApiUrls = [
  'https://exam-app-api.duckdns.org',  // HTTPS trước
  'http://exam-app-api.duckdns.org',    // HTTP dự phòng
  // ... các URL khác
];
```

### Cập Nhật Cấu Hình CORS Backend

Cập nhật dịch vụ backend của bạn để cho phép nguồn HTTPS:

**Tệp:** `backend-api/.env` và `backend-chat/.env`

```env
ALLOWED_ORIGINS=https://exam-app-api.duckdns.org,https://backend-chat.duckdns.org,http://exam-app-api.duckdns.org,http://backend-chat.duckdns.org
```

**Lưu Ý:** Giữ nguồn HTTP để tương thích ngược trong quá trình chuyển đổi.

## 🐛 Khắc Phục Sự Cố

### Vấn Đề: Không Tìm Thấy Chứng Chỉ

**Lỗi:**
```
nginx: [emerg] SSL_CTX_use_certificate_file("/etc/letsencrypt/live/...") failed
```

**Giải Pháp:**
```bash
# Xác minh chứng chỉ tồn tại
sudo ls -la /etc/letsencrypt/live/exam-app-api.duckdns.org/

# Kiểm tra quyền tệp
sudo chmod 644 /etc/letsencrypt/live/exam-app-api.duckdns.org/fullchain.pem
sudo chmod 600 /etc/letsencrypt/live/exam-app-api.duckdns.org/privkey.pem
```

### Vấn Đề: 502 Bad Gateway

**Lỗi:**
```
502 Bad Gateway
```

**Giải Pháp:**
```bash
# Xác minh dịch vụ backend đang chạy
curl http://localhost:3000/health
curl http://localhost:3001/health

# Kiểm tra nhật ký lỗi Nginx
sudo tail -f /var/log/nginx/error.log

# Xác minh URL proxy_pass đúng
sudo nginx -t
```

### Vấn Đề: Chứng Chỉ SSL Hết Hạn

**Lỗi:**
```
NET::ERR_CERT_DATE_INVALID
```

**Giải Pháp:**
```bash
# Gia hạn chứng chỉ
sudo certbot renew

# Tải lại Nginx
sudo systemctl reload nginx

# Xác minh gia hạn
sudo certbot certificates
```

### Vấn Đề: Cảnh Báo Nội Dung Hỗn Hợp

**Lỗi:**
```
Mixed Content: The page was loaded over HTTPS, but requested an insecure resource
```

**Giải Pháp:**
- Đảm bảo tất cả lời gọi API sử dụng URL HTTPS
- Cập nhật cấu hình ứng dụng Flutter
- Kiểm tra cài đặt CORS backend

### Vấn Đề: Kết Nối WebSocket Thất Bại

**Lỗi:**
```
WebSocket connection to 'wss://...' failed
```

**Giải Pháp:**
- Xác minh Socket.io được cấu hình cho HTTPS
- Kiểm tra cài đặt proxy WebSocket Nginx
- Đảm bảo tiêu đề `X-Forwarded-Proto` được đặt đúng

## 📊 Danh Sách Kiểm Tra Xác Minh

Sau khi nâng cấp lên HTTPS, xác minh những điều sau:

- [ ] HTTPS có thể truy cập: `curl https://exam-app-api.duckdns.org/health`
- [ ] HTTP chuyển hướng sang HTTPS: `curl -I http://exam-app-api.duckdns.org/health`
- [ ] Chứng chỉ SSL hợp lệ (không có cảnh báo trình duyệt)
- [ ] Dịch vụ backend phản hồi đúng
- [ ] Kết nối WebSocket hoạt động (cho dịch vụ chat)
- [ ] Ứng dụng Flutter có thể kết nối qua HTTPS
- [ ] Tự động gia hạn được cấu hình: `sudo certbot renew --dry-run`
- [ ] Tường lửa cho phép cổng 443
- [ ] Nhật ký Nginx không hiển thị lỗi SSL

## 🔒 Thực Hành Bảo Mật Tốt Nhất

1. **Sử Dụng Cấu Hình SSL Mạnh**
   - Chỉ TLS 1.2+
   - Bộ mã hóa hiện đại
   - HSTS được bật

2. **Giám Sát Chứng Chỉ Thường Xuyên**
   - Giám sát ngày hết hạn chứng chỉ
   - Thiết lập thông báo gia hạn
   - Kiểm tra quy trình gia hạn thường xuyên

3. **Giữ Certbot Cập Nhật**
   ```bash
   sudo apt update
   sudo apt upgrade certbot
   ```

4. **Giám Sát Nhật Ký Nginx**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   sudo tail -f /var/log/nginx/access.log
   ```

## 📚 Tài Nguyên Bổ Sung

- [Tài Liệu Let's Encrypt](https://letsencrypt.org/docs/)
- [Hướng Dẫn Người Dùng Certbot](https://eff-certbot.readthedocs.io/)
- [Cấu Hình SSL Nginx](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Kiểm Tra SSL Labs](https://www.ssllabs.com/ssltest/) - Kiểm tra cấu hình SSL của bạn

## ⚠️ Lưu Ý Quan Trọng

1. **Hết Hạn Chứng Chỉ**: Chứng chỉ Let's Encrypt hết hạn sau mỗi 90 ngày. Tự động gia hạn sẽ xử lý điều này, nhưng hãy giám sát nó.

2. **Giới Hạn Tốc Độ**: Let's Encrypt có giới hạn tốc độ:
   - 50 chứng chỉ mỗi tên miền đã đăng ký mỗi tuần
   - 5 chứng chỉ trùng lặp mỗi tuần

3. **Sao Lưu**: Luôn sao lưu cấu hình của bạn trước khi thay đổi.

4. **Kiểm Tra**: Kiểm tra trong môi trường staging trước khi triển khai sản xuất.

5. **Giám Sát**: Thiết lập giám sát cho việc hết hạn chứng chỉ và lỗi gia hạn.

---

**Cập Nhật Lần Cuối:** 2025
**Được Duy Trì Bởi:** Nhóm Ứng Dụng Quản Lý Thi - me NguyenCaoAnh XD
---

