# TÀI LIỆU HỖ TRỢ VIẾT BÁO CÁO BÀI TẬP LỚN
## HỌC PHẦN: TRIỂN KHAI VÀ QUẢN TRỊ HỆ THỐNG PHẦN MỀM
### ĐỀ TÀI 3: WEBSITE QUẢNG BÁ SẢN PHẨM (WORDPRESS)

- **Sinh viên thực hiện:** Lương Việt Anh
- **Mã số sinh viên (MSSV):** DTC245200063
- **Lớp:** CNTT
- **Khoa:** Công nghệ Thông tin - Trường Đại học Công nghệ Thông tin & Truyền thông (ICTU)
- **Giảng viên hướng dẫn:** Bộ môn Quản trị Mạng & Hệ thống
- **Repository GitHub:** [https://github.com/dtc245200063-alt/DTC245200063](https://github.com/dtc245200063-alt/DTC245200063)
- **Địa chỉ IP máy ảo VMware:** `192.168.102.128` (Ubuntu 24.04 LTS)

---

## MỤC LỤC BÁO CÁO VÀ DÀN Ý CHI TIẾT

```
LỜI CẢM ƠN
MỤC LỤC
DANH MỤC TỪ VIẾT TẮT
DANH MỤC BẢNG BIỂU & HÌNH VẼ
MỞ ĐẦU
CHƯƠNG 1: TỔNG QUAN HỆ THỐNG VÀ BÀI TOÁN TRIỂN KHAI
  1.1. Đặt vấn đề và mục tiêu đề tài
  1.2. Yêu cầu nghiệp vụ website quảng bá sản phẩm
  1.3. Khảo sát công nghệ sử dụng (Docker, WordPress, Nginx, Prometheus, Grafana, Loki)
CHƯƠNG 2: THIẾT KẾ KIẾN TRÚC VÀ TRIỂN KHAI HỆ THỐNG
  2.1. Kiến trúc phân tầng và phân vùng mạng (3-Tier Network Isolation)
  2.2. Đóng gói dịch vụ với Docker Compose
  2.3. Triển khai WordPress, Custom Post Type "Sản phẩm" và Seed dữ liệu mẫu
  2.4. Cấu hình Nginx Reverse Proxy, HTTPS tự ký và Security Headers
  2.5. Quản trị cơ sở dữ liệu MySQL và phpMyAdmin an toàn
CHƯƠNG 3: HỆ THỐNG GIÁM SÁT HIỆU NĂNG, LOG VÀ CẢNH BÁO TỰ ĐỘNG
  3.1. Thu thập số liệu hiệu năng với Prometheus, cAdvisor, Nginx & MySQL Exporters
  3.2. Trực quan hóa số liệu với Grafana (4 Dashboards chuyên sâu)
  3.3. Thu thập và tập trung hóa nhật ký (Log Aggregation) với Loki và Promtail
  3.4. Mô phỏng tấn công Brute-Force và kích hoạt Grafana Unified Alerting
CHƯƠNG 4: AN TOÀN HỆ THỐNG, TỐI ƯU VÀ ĐÁNH GIÁ THỰC NGHIỆM
  4.1. Các giải pháp bảo mật và Hardening toàn diện
  4.2. Kiểm thử tải, độ tin cậy và khả năng phục hồi (Clean-State Verification)
  4.3. Đánh giá kết quả đạt được so với yêu cầu
KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN
TÀI LIỆU THAM KHẢO
PHỤ LỤC: CÁC LỆNH VẬN HÀNH VÀ BẰNG CHỨNG THỰC NGHIỆM
```

---

## 1. BẢNG ÁNH XẠ NỘI DUNG BÁO CÁO, TỆP CẤU HÌNH VÀ BẰNG CHỨNG (EVIDENCE)

| Mục trong báo cáo | Tệp mã nguồn / Cấu hình trong Repository | Tệp bằng chứng (Evidence) / Script kiểm tra | Nội dung trọng tâm cần trình bày trong báo cáo |
|---|---|---|---|
| **1.1 - 1.3**<br/>Môi trường & Tổng quan | `docker-compose.yml`<br/>`.env.example` | `evidence/buoc0-moitruong.txt` | Cấu hình máy ảo Ubuntu 24.04 LTS, Docker Engine 27.x, Compose v2, thiết kế 12 microservices. |
| **2.1 - 2.2**<br/>Kiến trúc mạng & Docker | `docker-compose.yml` (mục `networks`) | `evidence/buoc6-hardening.txt`<br/>`scripts/verify_all.sh` | Phân vùng 3 mạng `de3_frontend_net`, `de3_backend_net` (internal), `de3_monitoring_net` (internal). |
| **2.3**<br/>WordPress & CPT Sản phẩm | `wordpress/mu-plugins/custom-post-type.php`<br/>`wordpress/scripts/install.sh`<br/>`wordpress/Dockerfile` | `evidence/buoc12-wordpress-db.txt`<br/>`scripts/test_step12.sh` | Custom Post Type `san-pham`, custom fields (giá, mã SP, tồn kho, tính năng), taxonomy danh mục, 12 sản phẩm mẫu có ảnh thực tế. |
| **2.4**<br/>Nginx Reverse Proxy & SSL | `nginx/conf.d/default.conf`<br/>`nginx/nginx.conf`<br/>`nginx/gen-cert.sh` | `evidence/buoc3-nginx.txt`<br/>`scripts/test_step3.sh` | Termination SSL (HTTPS port 443), TLSv1.2/1.3, HSTS, CSP, X-Frame-Options, chuyển hướng 80 -> 443, proxy pass WP, phpMyAdmin, Grafana. |
| **2.5**<br/>MySQL & phpMyAdmin | `db/my.cnf`<br/>`db/init.sql`<br/>`docker-compose.yml` (service `mysql`) | `evidence/buoc12-wordpress-db.txt`<br/>`evidence/buoc6-hardening.txt` | MySQL 8.0, cấu hình UTF8MB4, thu hẹp quyền user `wp_app` (chỉ trên `wordpress.*`, không có quyền GRANT/SUPER), phpMyAdmin qua proxy. |
| **3.1**<br/>Prometheus & Exporters | `prometheus/prometheus.yml`<br/>`docker-compose.yml` (`cadvisor`, `nginx-exporter`, `mysql-exporter`) | `evidence/buoc4-giamsat.txt`<br/>`scripts/test_step4.sh` | Cơ chế Pull metrics 15s interval, 4 jobs: cadvisor:8080, mysql:9104, nginx:9113, prometheus:9090. Tất cả đều UP (1). |
| **3.2**<br/>Grafana Dashboards | `grafana/provisioning/dashboards/`<br/>`grafana/dashboards/*.json` | `evidence/buoc4-giamsat.txt` | 4 Dashboards chuẩn hóa: Containers Engine, Nginx Status, MySQL Performance, Centralized Logs Viewer. Tích hợp thanh điều hướng breadcrumb. |
| **3.3**<br/>Loki & Promtail | `loki/loki-config.yml`<br/>`promtail/promtail-config.yml` | `evidence/buoc5-logql.txt`<br/>`scripts/test_logql.sh` | Thu thập nhật ký container qua Docker Socket, gán label động `container_name`, phân tích JSON stream, truy vấn LogQL đa chiều. |
| **3.4**<br/>Brute-Force & Alerting | `grafana/provisioning/alerting/rules.yml`<br/>`alert-sink/app.py`<br/>`docs/su-co-bruteforce.md` | `evidence/buoc5-sucodo.txt`<br/>`scripts/simulate_bruteforce.sh` | Kịch bản tấn công Brute-force `wp-login.php`, phát hiện chuỗi lỗi `401/403/200 POST` tăng đột biến, Alert Rule 3-stage kích hoạt trạng thái **FIRING**, bắn Webhook tới Alert-Sink. |
| **3.4 (b)**<br/>Báo cáo sự cố an ninh | `docs/su-co-bruteforce.md` | `docs/su-co-bruteforce.md` | Báo cáo sự cố chuẩn SOC: Mô tả, Thời gian phát hiện, Tác động, Nguyên nhân gốc rễ, Biện pháp cô lập tức thời, Kế hoạch khắc phục dài hạn. |
| **4.1**<br/>Hardening & Bảo mật | `scripts/apply_hardening.sh`<br/>`wordpress/mu-plugins/hardening.php`<br/>`nginx/conf.d/default.conf` | `evidence/buoc6-hardening.txt` | 7 biện pháp: 3-Tier Network, Non-root containers, MySQL Least Privilege, Rate Limiting (limit_req), Ẩn WP version, Chặn User Enumeration, Tường lửa UFW. |
| **4.2**<br/>Kiểm thử Clean-State | `scripts/verify_clean_state.sh` | `evidence/final-smoke-test.txt` | Quy trình kiểm thử tính toàn vẹn và khả năng tái lập: Khởi tạo từ repo sạch, cấu hình, sinh cert, boot 12 containers, kiểm tra 100% endpoint pass. |

---

## 2. DANH MỤC ẢNH CẦN CHỤP VÀ CHÚ THÍCH MẪU CHO BÁO CÁO

Để báo cáo đạt điểm tối đa (thể hiện tính trung thực, chuyên nghiệp và có sản phẩm thực tế), sinh viên mở trình duyệt trên máy thật hoặc máy ảo và chụp lại 12 hình ảnh sau:

### Hình 1: Trang chủ Website giới thiệu sản phẩm (Giao diện chính)
- **URL truy cập:** `https://192.168.102.128/` (hoặc `http://localhost:8080/`)
- **Nội dung hiển thị:** Banner thương hiệu "TechZone - Sản Phẩm Công Nghệ Đỉnh Cao", danh sách lưới hiển thị các sản phẩm (Laptop Gaming ASUS, MacBook Pro M3, Bàn phím cơ...).
- **Cách chụp:** Chụp toàn màn hình trình duyệt hoặc vùng nội dung từ thanh địa chỉ URL xuống chân trang.
- **Chú thích mẫu (Caption):** *Hình 2.1: Giao diện trang chủ website quảng bá sản phẩm công nghệ WordPress với chứng chỉ bảo mật HTTPS.*

### Hình 2: Trang chi tiết một sản phẩm (Custom Fields & Metadata)
- **URL truy cập:** `https://192.168.102.128/san-pham/laptop-gaming-asus-rog-strix-g16/`
- **Nội dung hiển thị:** Tiêu đề sản phẩm, hình ảnh minh họa, giá niêm yết, mã SKU, tình trạng kho hàng, bảng thông số kỹ thuật chi tiết.
- **Chú thích mẫu (Caption):** *Hình 2.2: Trang chi tiết sản phẩm hiển thị các trường dữ liệu mở rộng (Custom Fields) và thông số kỹ thuật.*

### Hình 3: Giao diện Quản trị WordPress (Custom Post Type "Sản phẩm")
- **URL truy cập:** `https://192.168.102.128/wp-admin/edit.php?post_type=san_pham`
- **Tài khoản:** `quantri` / *(mật khẩu trong `.env`)*
- **Nội dung hiển thị:** Danh sách quản lý 12 sản phẩm trong WordPress Dashboard, các cột Mã SP, Giá bán, Danh mục sản phẩm, Ngày đăng.
- **Chú thích mẫu (Caption):** *Hình 2.3: Khu vực quản trị danh mục và sản phẩm Custom Post Type trong trang quản trị WordPress.*

### Hình 4: Quản trị Cơ sở dữ liệu qua phpMyAdmin
- **URL truy cập:** `https://192.168.102.128/phpmyadmin/`
- **Tài khoản:** `wp_app` / *(mật khẩu trong `.env`)*
- **Nội dung hiển thị:** Giao diện phpMyAdmin kết nối đến cơ sở dữ liệu `wordpress`, cấu trúc các bảng `wp_posts`, `wp_postmeta`, `wp_terms`.
- **Lưu ý:** Chỉ thấy database `wordpress` do user `wp_app` đã được áp dụng nguyên tắc đặc quyền tối thiểu (Least Privilege), không thấy các DB hệ thống (`mysql`, `performance_schema`).
- **Chú thích mẫu (Caption):** *Hình 2.4: Giao diện phpMyAdmin kết nối CSDL MySQL nội bộ dưới quyền người dùng an toàn wp_app.*

### Hình 5: Chứng chỉ bảo mật SSL/TLS và Security Headers của Nginx
- **Thao tác:** Bấm vào biểu tượng ổ khóa cạnh URL `https://192.168.102.128/` -> Chọn "Chứng chỉ hợp lệ" (Certificate Viewer) -> Hiển thị CN `192.168.102.128`, Issuer `DTC245200063`. Hoặc mở F12 Network tab xem response headers: `Strict-Transport-Security`, `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`.
- **Chú thích mẫu (Caption):** *Hình 2.5: Thông tin chứng chỉ số SSL tự ký và các tiêu đề bảo mật (Security Headers) do Nginx Reverse Proxy thiết lập.*

### Hình 6: Trạng thái cAdvisor (Theo dõi tài nguyên Container)
- **URL truy cập:** `http://192.168.102.128:8080/containers/` (nếu mở cổng) hoặc chụp thông qua cAdvisor metrics trên Prometheus/Grafana.
- **Nội dung hiển thị:** Biểu đồ CPU, Memory sử dụng theo thời gian thực của từng container Docker.
- **Chú thích mẫu (Caption):** *Hình 3.1: Giao diện cAdvisor theo dõi tài nguyên phần cứng (CPU/RAM/Network) của các container.*

### Hình 7: Prometheus Target Health Status
- **URL truy cập:** Truy cập qua SSH tunnel hoặc giao diện Prometheus: `http://localhost:9090/targets` (hoặc curl/bằng chứng terminal `evidence/buoc4-giamsat.txt`).
- **Nội dung hiển thị:** Bảng Scrape Targets hiển thị 4/4 jobs ở trạng thái **UP (1)** màu xanh lá (`cadvisor`, `mysql`, `nginx`, `prometheus`).
- **Chú thích mẫu (Caption):** *Hình 3.2: Danh sách các Scrape Target trên Prometheus hoạt động ổn định (100% UP).*

### Hình 8: Grafana Dashboard - Giám sát Container Docker Toàn diện
- **URL truy cập:** `https://192.168.102.128/grafana/d/docker-containers/`
- **Nội dung hiển thị:** Dashboard trực quan hóa tổng số container đang chạy (12 containers), CPU usage %, Memory usage MB, Network I/O.
- **Chú thích mẫu (Caption):** *Hình 3.3: Dashboard giám sát tài nguyên và trạng thái thực thi của 12 Docker Containers trên Grafana.*

### Hình 9: Grafana Dashboard - Giám sát Web Server Nginx & CSDL MySQL
- **URL truy cập:** `https://192.168.102.128/grafana/d/nginx-performance/` hoặc `mysql-performance/`
- **Nội dung hiển thị:** Lưu lượng truy cập Nginx (Active connections, Requests per second, HTTP Status Codes 2xx/3xx/4xx/5xx) và MySQL (Queries/sec, Buffer Pool Size, Connections).
- **Chú thích mẫu (Caption):** *Hình 3.4: Dashboard giám sát chuyên sâu hiệu năng Nginx Web Server và MySQL Database.*

### Hình 10: Grafana Dashboard - Nhật ký tập trung (Loki Centralized Logs)
- **URL truy cập:** `https://192.168.102.128/grafana/d/centralized-logs/` (hoặc tab Explore với Data Source Loki)
- **Nội dung hiển thị:** Luồng log thời gian thực từ 12 containers được thu thập bởi Promtail, bộ lọc theo `{container_name=~".+"}`, thanh histogram đếm số lượng log line.
- **Chú thích mẫu (Caption):** *Hình 3.5: Giao diện trực quan hóa và truy vấn nhật ký tập trung bằng Grafana Loki và Promtail.*

### Hình 11: Grafana Unified Alerting - Cảnh báo Brute-Force kích hoạt (FIRING)
- **URL truy cập:** `https://192.168.102.128/grafana/alerting/list`
- **Nội dung hiển thị:** Cảnh báo `WordPress-BruteForce-Detected` chuyển sang màu đỏ **[FIRING]** kèm thông báo threshold vượt ngưỡng (ví dụ: `[FIRING:1] BruteForce WordPress Alert`).
- **Chú thích mẫu (Caption):** *Hình 3.6: Quy tắc cảnh báo Grafana Alerting tự động kích hoạt trạng thái FIRING khi phát hiện tấn công dò quét mật khẩu.*

### Hình 12: Nhật ký Alert-Sink nhận Webhook và Khắc phục sự cố
- **Thao tác:** Chụp màn hình terminal lệnh: `docker compose logs alert-sink --tail=30` hoặc xem file `evidence/buoc5-sucodo.txt`.
- **Nội dung hiển thị:** Dịch vụ Alert-Sink (Flask HTTP Server port 9099) nhận payload POST `/webhook` từ Grafana với trạng thái `status: firing`, alertname: `WordPress-BruteForce-Detected`.
- **Chú thích mẫu (Caption):** *Hình 3.7: Nhật ký dịch vụ tiếp nhận cảnh báo Alert-Sink ghi nhận thành công payload Webhook từ Grafana Alerting.*

### Hình 13: Đánh giá Bảo mật & Hardening (Mạng 3 lớp & UFW)
- **Thao tác:** Chụp màn hình terminal chạy script `sudo ./scripts/apply_hardening.sh` hoặc file `evidence/buoc6-hardening.txt`.
- **Nội dung hiển thị:** 7 mục kiểm tra PASS (Mạng phân tầng, Non-root, Least Privilege DB, Rate Limiting 429, Chặn user enum 403, Tường lửa UFW active).
- **Chú thích mẫu (Caption):** *Hình 4.1: Kết quả kiểm tra tự động 7 tiêu chí làm cứng an toàn hệ thống (System Hardening).*

---

## 3. CÁC ĐOẠN VĂN MẪU ĐƯA VÀO BÁO CÁO

### 3.1. Mô tả giải pháp phân vùng mạng 3 lớp (3-Tier Network Architecture)
> *"Để bảo vệ toàn diện hệ thống theo nguyên tắc phòng thủ theo chiều sâu (Defense in Depth), toàn bộ các dịch vụ được phân chia thành 3 mạng Docker bridge biệt lập:*
> 1. *`de3_frontend_net` (172.28.1.0/24): Vùng mạng công cộng, nơi Nginx Reverse Proxy tiếp nhận lưu lượng từ người dùng bên ngoài và chuyển tiếp vào WordPress, phpMyAdmin và Grafana.*
> 2. *`de3_backend_net` (172.28.2.0/24): Vùng mạng dữ liệu nội bộ được cấu hình `internal: true`. Mạng này hoàn toàn bị ngắt định tuyến ra Internet và không cho phép các container giám sát kết nối tới. Máy chủ MySQL chỉ hiện diện tại đây và chỉ chấp nhận kết nối từ WordPress, phpMyAdmin và MySQL Exporter.*
> 3. *`de3_monitoring_net` (172.28.3.0/24): Vùng mạng giám sát nội bộ được cấu hình `internal: true`. Chứa các dịch vụ giám sát gồm Prometheus, Loki, cAdvisor, Nginx Exporter, MySQL Exporter, Promtail và Alert-Sink. Prometheus định kỳ cào số liệu và Promtail đẩy nhật ký vào Loki qua mạng này mà không làm ảnh hưởng đến hiệu năng hay bảo mật của tầng ứng dụng và dữ liệu."*

### 3.2. Mô tả cơ chế phát hiện và cảnh báo Brute-Force thời gian thực
> *"Khi kẻ tấn công sử dụng các công cụ tự động dò quét mật khẩu quản trị vào tệp tin `wp-login.php`, Promtail liên tục theo dõi log stream của Nginx thông qua Docker Socket `/var/run/docker.sock` và đẩy về Loki dưới dạng JSON nhật ký có cấu trúc. Grafana Unified Alerting định kỳ mỗi 10 giây thực thi truy vấn LogQL:*
> ```logql
> sum(count_over_time({container_name="de3_nginx"} |= "POST /wp-login.php" [1m]))
> ```
> *Dữ liệu timeseries sau đó được xử lý qua hàm giảm chiều (Reduce: last, drop non-numeric) và đối chiếu với ngưỡng cảnh báo (Threshold: Is Above 5). Nếu trong vòng 1 phút ghi nhận quá 5 lần thử đăng nhập thất bại, Alert Rule lập tức kích hoạt trạng thái FIRING và gửi gói tin Webhook JSON chứa đầy đủ ngữ cảnh sự cố đến dịch vụ Alert-Sink (cổng nội bộ 9099) để đội ngũ quản trị kịp thời cô lập địa chỉ IP tấn công."*

### 3.3. Mô tả các biện pháp làm cứng WordPress (WordPress Hardening)
> *"Để giảm thiểu bề mặt tấn công trên nền tảng WordPress, nhóm tác giả đã xây dựng Must-Use Plugin (`wordpress/mu-plugins/hardening.php`) tự động kích hoạt mà không thể bị vô hiệu hóa từ giao diện admin:*
> - *Ẩn thông tin phiên bản WordPress khỏi thẻ meta HTML, RSS Feed và URL script/style nhằm chống thu thập dấu vết (Fingerprinting).*
> - *Ngăn chặn tấn công dò quét danh sách tài khoản (User Enumeration) bằng cách trả về mã lỗi HTTP 403 Forbidden hoặc chuyển hướng an toàn khi có request dạng `/?author=1` hoặc gọi tới REST API `/wp-json/wp/v2/users`.*
> - *Vô hiệu hóa giao thức XML-RPC (`xmlrpc.php`) nhằm triệt tiêu nguy cơ tấn công từ chối dịch vụ (DDoS Pingback amplification) và tấn công Brute-force qua hàm `system.multicall`.*
> - *Kết hợp với cơ chế Rate Limiting tại Nginx (`limit_req_zone $binary_remote_addr zone=wp_login:10m rate=5r/m;`) giới hạn tối đa 5 yêu cầu/phút vào trang đăng nhập, tự động trả về lỗi HTTP 429 Too Many Requests khi vượt ngưỡng."*

---

## 4. BẢNG THÔNG SỐ VÀ CẤU HÌNH ĐỐI CHỨNG DÀNH CHO THẦY CÔ CHẤM BÀI

| Hạng mục đánh giá | Yêu cầu của đề bài | Kết quả thực tế đạt được | Vị trí kiểm tra / Lệnh chứng minh |
|---|---|---|---|
| **Dịch vụ chính** | WordPress + CSDL MySQL | Chạy ổn định trên Docker, khởi tạo tự động bằng WP-CLI | `https://192.168.102.128/`<br/>`docker compose ps` |
| **Nội dung Đề tài 3** | Quảng bá sản phẩm | 12 sản phẩm công nghệ thực tế, có CPT, Custom fields, ảnh sản phẩm | Menu "Sản phẩm" trên web hoặc xem `wordpress/mu-plugins/custom-post-type.php` |
| **Reverse Proxy & SSL** | Nginx HTTPS | Chứng chỉ SSL tự ký x509, TLS 1.2/1.3, HSTS, chuyển hướng tự động 80->443 | `https://192.168.102.128/`<br/>`curl -kI https://192.168.102.128/` |
| **Giám sát hiệu năng** | Prometheus + Grafana | 4 Scrape targets UP 100%, 4 Dashboards trực quan hóa, liên kết breadcrumb | `https://192.168.102.128/grafana/`<br/>`evidence/buoc4-giamsat.txt` |
| **Quản trị nhật ký** | Thu thập log tập trung | Loki 2.9 + Promtail 3.6 thu thập toàn bộ 12 containers qua Docker socket | Dashboards Logs trên Grafana<br/>`evidence/buoc5-logql.txt` |
| **Cảnh báo tự động** | Kịch bản sự cố & Alerting | Mô phỏng Brute-Force, Grafana Alerting kích hoạt FIRING, đẩy Webhook tới Alert-Sink | `scripts/simulate_bruteforce.sh`<br/>`docs/su-co-bruteforce.md` |
| **Bảo mật & Hardening** | Cách ly mạng, Least privilege | Mạng 3 lớp (2 internal), User non-root, DB user không có quyền quản trị, Rate Limit, UFW | `scripts/apply_hardening.sh`<br/>`evidence/buoc6-hardening.txt` |
| **Triển khai sạch** | Triển khai lại từ đầu (Clean-state) | Script tự động hóa 100%, không lỗi xung đột, kiểm thử thành công | `scripts/verify_clean_state.sh`<br/>`evidence/final-smoke-test.txt` |

---

## 5. HƯỚNG DẪN MỞ BẢO VỆ VÀ THUYẾT MINH BÀI TẬP LỚN

Khi trình bày trước hội đồng hoặc giảng viên, sinh viên thực hiện theo trình tự sau:
1. **Mở trình duyệt truy cập:** `https://192.168.102.128/` giới thiệu trang chủ website sản phẩm công nghệ TechZone (Đề tài 3).
2. **Trình bày cấu trúc dữ liệu:** Bấm vào một sản phẩm cụ thể, giải thích về Custom Post Type, Custom Fields (Giá, Mã SP, Cấu hình).
3. **Mở Grafana:** `https://192.168.102.128/grafana/` trình bày 4 dashboard:
   - Dashboard Containers: Thấy 12 containers đang hoạt động.
   - Dashboard MySQL & Nginx: Xem tải truy cập.
   - Dashboard Logs: Trình bày truy vấn LogQL lọc nhật ký của WordPress hoặc Nginx.
4. **Trình bày kịch bản bảo mật:**
   - Mở terminal chạy `./scripts/simulate_bruteforce.sh`.
   - Mở màn hình Grafana Alerting cho thầy cô thấy Rule chuyển từ `Normal` sang `Firing`.
   - Xem log của Alert-Sink ghi nhận thông báo.
5. **Chứng minh Hardening:**
   - Chạy `./scripts/apply_hardening.sh` cho thấy 7 tiêu chí đều đạt chuẩn bảo mật.
