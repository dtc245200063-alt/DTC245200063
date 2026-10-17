# BÁO CÁO PHÂN TÍCH SỰ CỐ AN TOÀN THÔNG TIN
## Tấn công dò quét mật khẩu (Brute-Force Attack) vào cổng quản trị WordPress

- **Sinh viên thực hiện:** Lương Việt Anh
- **MSSV:** DTC245200063
- **Lớp:** CNTT
- **Đề tài:** Đề tài 3 - Website Quảng bá Sản phẩm (WordPress)
- **Hệ thống giám sát & ghi log:** Prometheus, Grafana Alerting, Loki, Promtail

---

## 1. Mô tả sự cố (Incident Description)

### 1.1. Bối cảnh
Vào thời điểm ghi nhận trong quá trình vận hành hệ thống, cổng đăng nhập quản trị `/wp-login.php` của website WordPress bất ngờ tiếp nhận một lượng lớn các yêu cầu HTTP POST liên tiếp trong một khoảng thời gian cực ngắn (~10 giây).

### 1.2. Dấu hiệu nhận biết
- Lượng truy cập HTTP POST bất thường tập trung vào duy nhất URI `/wp-login.php`.
- Container `de3_wordpress` liên tục ghi nhận các dòng log `LOGIN_FAILED` với lý do `wrong_password`.
- Hệ thống giám sát Log tập trung (Loki) ghi nhận sự gia tăng đột biến của hàm đếm lỗi đăng nhập theo phút `sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))`.

### 1.3. Phân loại sự cố
- **Hình thức tấn công:** Password Guessing / Dictionary Attack / Brute-Force Authentication Attack.
- **Mục tiêu bị nhắm tới:** Tài khoản quản trị cấp cao `quantri`.
- **Mức độ nghiêm trọng (Severity):** **CRITICAL** (Nguy cơ bị chiếm đoạt toàn quyền quản trị trang web và cơ sở dữ liệu nếu mật khẩu yếu).

---

## 2. Phát hiện và Kích hoạt Cảnh báo (Detection & Alerting)

### 2.1. Cơ chế giám sát
Hệ thống sử dụng cơ chế giám sát log tập trung kết hợp quy tắc cảnh báo tự động:
1. **Promtail (`de3_promtail`):** Thu thập toàn bộ log container Docker qua socket `/var/run/docker.sock` theo thời gian thực và đẩy về Loki.
2. **Loki (`de3_loki`):** Lưu trữ và lập chỉ mục log của các dịch vụ (`job="webapp"`, `job="nginx"`, `job="mysql"`).
3. **Grafana Unified Alerting:** Thiết lập quy tắc giám sát tự động với chu kỳ đánh giá 10 giây.

### 2.2. Quy tắc cảnh báo (Alert Rule)
- **Tên quy tắc:** `WP - Brute force login`
- **Thư mục:** `Security` / Nhóm: `WP - Security Alerts`
- **Truy vấn LogQL (Condition A):**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
  ```
- **Điều kiện ngưỡng (Condition B - Threshold):** `Value > 5`
- **Thời gian duy trì (For):** `0s` (Kích hoạt ngay khi vượt ngưỡng)
- **Mức độ (Severity):** `critical`

### 2.3. Quá trình kích hoạt cảnh báo (Alert Lifecycle)
1. **Trước sự cố:** Tỷ lệ lỗi đăng nhập bằng 0, Alert Rule ở trạng thái `Normal (OK)`.
2. **Khi xảy ra sự cố:** Kẻ tấn công gửi liên tiếp 20 request đăng nhập sai. Trong vòng 10 giây, số lượng `LOGIN_FAILED` tăng vọt lên 20 (vượt xa ngưỡng 5).
3. **Kích hoạt Firing:** Alert Rule chuyển sang trạng thái **FIRING**.
4. **Phát thông báo:** Hệ thống thông báo tự động (Notification Policy) gửi Webhook HTTP POST tới dịch vụ `alert-sink` (`http://alert-sink:9099/alert`) để lưu trữ vết và hiển thị trên dashboard điều hành an ninh mạng.

---

## 3. Quá trình Điều tra và Truy vết Log (Forensic & Log Investigation)

Sử dụng ngôn ngữ truy vấn LogQL thông qua giao diện Grafana Explore và Loki API để bóc tách hành vi của kẻ tấn công:

### 3.1. Xác định địa chỉ IP nguồn và tài khoản mục tiêu
- **Truy vấn LogQL:**
  ```logql
  {job="webapp"} |= "LOGIN_FAILED"
  ```
- **Kết quả trích xuất:**
  ```text
  LOGIN_FAILED ip=192.168.102.128 user=quantri reason=wrong_password
  LOGIN_FAILED ip=192.168.102.128 user=quantri reason=wrong_password
  LOGIN_FAILED ip=192.168.102.128 user=quantri reason=wrong_password
  ...
  ```
- **Phân tích:**
  - **Địa chỉ IP nguồn:** `192.168.102.128` (hoặc IP proxy/máy trạm thực hiện tấn công).
  - **Tài khoản đích:** `quantri` (Xác nhận tài khoản tồn tại trên hệ thống, kẻ tấn công đang tìm cách đoán mật khẩu tài khoản này).
  - **Lý do thất bại:** `wrong_password`.

### 3.2. Đo lường cường độ tấn công
- **Truy vấn LogQL:**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [5m]))
  ```
- **Kết quả:** Tổng cộng 20 lần thử sai trong vòng 10 giây (trung bình 2 requests/giây).

### 3.3. Đối chiếu nhật ký truy cập Nginx Reverse Proxy
- **Truy vấn LogQL:**
  ```logql
  {job="nginx"} |= "POST /wp-login.php"
  ```
- **Kết quả trích xuất:**
  ```text
  192.168.102.128 - - [17/Oct/2026:05:38:10 +0000] "POST /wp-login.php HTTP/1.1" 200 10105 "-" "curl/8.18.0" "-" rt=0.210
  192.168.102.128 - - [17/Oct/2026:05:38:11 +0000] "POST /wp-login.php HTTP/1.1" 200 10105 "-" "curl/8.18.0" "-" rt=0.208
  ...
  ```
- **Phân tích đối chiếu:**
  - Mã phản hồi HTTP: `200 OK` (WordPress nạp lại trang đăng nhập kèm thông báo sai mật khẩu).
  - User-Agent: `curl/8.18.0` (Cho thấy kẻ tấn công sử dụng công cụ tự động / kịch bản script chứ không phải người dùng qua trình duyệt thông thường).
  - Thời gian xử lý (`rt`): ~0.2s mỗi request, không gây sập máy chủ nhưng chiếm dụng tài nguyên PHP-FPM / Apache.

---

## 4. Đề xuất Biện pháp Xử lý và Khắc phục (Mitigation & Hardening)

Để triệt tiêu nguy cơ từ các cuộc tấn công Brute-Force tương tự, triển khai các biện pháp phòng thủ đa tầng:

### 4.1. Khắc phục tức thời (Immediate Response)
1. **Chặn IP kẻ tấn công:** Sử dụng `iptables` hoặc cấu hình Nginx chặn tạm thời:
   ```nginx
   deny 192.168.102.128;
   ```
2. **Kiểm tra tính toàn vẹn của tài khoản:** Xác minh tài khoản `quantri` chưa bị đăng nhập trái phép; đổi mật khẩu quản trị sang chuỗi ký tự ngẫu nhiên phức tạp (trên 20 ký tự).

### 4.2. Khắc phục dài hạn và Gia cố hệ thống (Long-term Hardening)
1. **Giới hạn tốc độ yêu cầu (Rate Limiting) trên Nginx Reverse Proxy:**
   - Cấu hình vùng nhớ `limit_req_zone` riêng cho `/wp-login.php`:
     ```nginx
     limit_req_zone $binary_remote_addr zone=wp_login_limit:10m rate=5r/m;

     location = /wp-login.php {
         limit_req zone=wp_login_limit burst=3 nodelay;
         proxy_pass http://wordpress:80;
         # Giữ nguyên proxy headers...
     }
     ```
   - Khi vượt quá tốc độ, Nginx sẽ từ chối ngay lập tức với mã HTTP `429 Too Many Requests` (hoặc `503`), ngăn chặn yêu cầu chạm tới Apache và MySQL.
2. **Kích hoạt Xác thực Hai yếu tố (Two-Factor Authentication - 2FA):**
   - Áp dụng 2FA bằng TOTP (Google Authenticator) cho toàn bộ tài khoản có quyền `administrator` và `editor`.
3. **Ẩn hoặc Đổi URL đăng nhập quản trị:**
   - Thay đổi đường dẫn `/wp-login.php` thành một URI bí mật hoặc giới hạn chỉ cho phép truy cập từ dải mạng nội bộ (Internal VPN / Whitelist IP).
4. **Vô hiệu hóa XML-RPC:**
   - Đã được triển khai tại Bước 3 trong `nginx.conf` (`location = /xmlrpc.php { deny all; return 403; }`), loại bỏ hoàn toàn kênh tấn công Brute-Force phổ biến qua XML-RPC multicall.
5. **Giám sát và Khóa tự động (Fail2ban / CrowdSec):**
   - Kết nối Loki log stream với cơ chế khóa IP tự động tại tầng tường lửa Linux (UFW/iptables).

---

## 5. Bài học Kinh nghiệm (Lessons Learned)

1. **Tầm quan trọng của Log tập trung:** Nếu chỉ dựa vào log cục bộ trên từng container, việc phát hiện sự cố sẽ bị trễ và khó đối chiếu tương quan giữa Reverse Proxy (Nginx) và Ứng dụng (WordPress).
2. **Alerting chủ động:** Việc cấu hình Alert Rule tự động phát cảnh báo sang kênh webhook (`alert-sink`) giúp đội ngũ quản trị phản ứng trong vòng vài giây thay vì chờ đợi người dùng báo cáo.
3. **Phòng thủ theo chiều sâu (Defense-in-Depth):** Cần kết hợp phòng thủ tại tầng mạng (Tường lửa/Rate Limiting), tầng Web Server (Nginx security rules), và tầng Ứng dụng (Mật khẩu mạnh, 2FA, Giám sát sự kiện đăng nhập).
