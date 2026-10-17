# Đề tài 3: Website Quảng bá Sản phẩm (WordPress)

## Thông tin sinh viên
- **Họ và tên:** Lương Việt Anh
- **Mã sinh viên:** DTC245200063
- **Lớp:** CNTT
- **Học phần:** Triển khai và Quản trị Hệ thống Phần mềm
- **Repository GitHub:** [https://github.com/dtc245200063-alt/DTC245200063](https://github.com/dtc245200063-alt/DTC245200063)

---

## 1. Giới thiệu hệ thống
Hệ thống website quảng bá sản phẩm đặc sản trà và cà phê Việt Nam sử dụng nền tảng WordPress kết hợp MySQL 8, phpMyAdmin, Nginx reverse proxy với HTTPS tự ký và các tiêu chuẩn bảo mật cao cấp (Security Headers, cấm truy cập file nhạy cảm), hệ thống giám sát Prometheus + Grafana và hệ thống ghi log tập trung Loki + Promtail.

Toàn bộ hệ thống được container hoá bằng Docker và quản lý thống nhất qua Docker Compose.

---

## 2. Hướng dẫn sinh chứng chỉ SSL tự ký (HTTPS)
Dự án sử dụng Nginx làm Reverse Proxy và kích hoạt HTTPS với chứng chỉ tự ký có SAN (Subject Alternative Name) bao gồm IP máy chủ và localhost.

Script tự động sinh chứng chỉ được đặt tại `nginx/gen-cert.sh`:
```bash
# Cấp quyền thực thi và chạy script (mặc định cho IP: 192.168.102.128)
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh 192.168.102.128
```

Script sẽ tạo ra:
- `nginx/certs/server.crt`: Chứng chỉ công khai (Certificate).
- `nginx/certs/server.key`: Khóa bí mật (Private Key - được bảo vệ và đã loại trừ khỏi Git theo `.gitignore`).

---

## 3. Khởi chạy hệ thống bằng Docker Compose
Sau khi tạo file `.env` từ `.env.example` và sinh chứng chỉ SSL:
```bash
docker compose up -d --build
```

---

## 4. Địa chỉ truy cập dịch vụ (HTTPS)
- **Website chính:** [https://192.168.102.128/](https://192.168.102.128/)
- **Trang danh mục sản phẩm:** [https://192.168.102.128/san-pham/](https://192.168.102.128/san-pham/)
- **Quản trị WordPress:** [https://192.168.102.128/wp-admin/](https://192.168.102.128/wp-admin/)
- **phpMyAdmin:** [https://192.168.102.128/phpmyadmin/](https://192.168.102.128/phpmyadmin/)
- **Hệ thống giám sát Grafana:** [https://192.168.102.128/grafana/](https://192.168.102.128/grafana/)

> **Lưu ý về chứng chỉ tự ký:** Khi truy cập lần đầu qua trình duyệt, do chứng chỉ là tự ký, trình duyệt sẽ hiển thị cảnh báo bảo mật. Nhấp vào **Nâng cao (Advanced)** -> Chọn **Tiếp tục truy cập (Proceed to 192.168.102.128)** để vào giao diện.

---

## 5. Hệ thống Giám sát (Monitoring Architecture)
Hệ thống sử dụng mô hình giám sát tập trung qua mạng nội bộ Docker (`de3_network`):
- **Prometheus:** Thu thập chỉ số (metrics) định kỳ mỗi 15 giây từ các Exporter.
- **cAdvisor:** Giám sát mức độ tiêu thụ tài nguyên thực tế (CPU %, RAM, Network I/O) của từng container.
- **Nginx Prometheus Exporter:** Đọc chỉ số kết nối (active/reading/writing/waiting) và tần suất request từ `/nginx_status`.
- **MySQL Exporter:** Thu thập chỉ số hiệu năng cơ sở dữ liệu (Queries/sec, Connections, Threads Running, InnoDB Buffer Pool).
- **Grafana:** Trực quan hóa dữ liệu với 3 Dashboard chuyên dụng được nạp tự động (Provisioning):
  1. `WP - Containers`: Tải CPU, RAM, Network I/O từng container.
  2. `WP - Nginx`: Kết nối, tốc độ request, handled vs accepted.
  3. `WP - MySQL`: Tần suất truy vấn, trạng thái luồng xử lý, bộ nhớ đệm InnoDB.

