# Đề tài 3: Website Quảng bá Sản phẩm (WordPress)

## Thông tin sinh viên
- **Họ và tên:** Lương Việt Anh
- **Mã sinh viên:** DTC245200063
- **Lớp:** CNTT
- **Học phần:** Triển khai và Quản trị Hệ thống Phần mềm
- **Repository GitHub:** [https://github.com/dtc245200063-alt/DTC245200063](https://github.com/dtc245200063-alt/DTC245200063)

## Giới thiệu hệ thống
Hệ thống website quảng bá sản phẩm đặc sản trà và cà phê Việt Nam sử dụng nền tảng WordPress kết hợp MySQL 8, phpMyAdmin, Nginx reverse proxy với HTTPS tự ký và bảo mật, hệ thống giám sát Prometheus + Grafana và hệ thống ghi log tập trung Loki + Promtail.

Toàn bộ hệ thống được container hoá bằng Docker và triển khai bằng Docker Compose qua một lệnh duy nhất:
```bash
docker compose up -d
```

*(Chi tiết hướng dẫn cài đặt và vận hành sẽ được cập nhật đầy đủ qua từng bước)*
