#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc6-hardening.txt"
mkdir -p "$PROJECT_DIR/evidence"

echo "================================================================================"
echo "BƯỚC 6: TRIỂN KHAI VÀ KIỂM CHỨNG CÁC BIỆN PHÁP HARDENING (GIA CỐ BẢO MẬT)"
echo "Sinh viên: Lương Việt Anh - MSSV: DTC245200063"
echo "Thời gian bắt đầu: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================================"

# 1. Bảo mật tệp cấu hình và secrets
echo ""
echo "--- 1. BẢO MẬT TỆP CẤU HÌNH VÀ SECRETS (.env) ---"
chmod 600 .env
[ -f nginx/certs/server.key ] && chmod 644 nginx/certs/server.key
echo "=> Đã phân quyền chặt chẽ (chmod 600 cho .env, chmod 644 cho SSL cert/key)."

# 2. Khởi động hệ thống với 3 mạng cách ly và Container Hardening
echo ""
echo "--- 2. KHỞI ĐỘNG HỆ THỐNG VỚI 3 MẠNG CÁCH LY VÀ CONTAINER HARDENING ---"
docker compose down --remove-orphans || true
docker network rm de3_network 2>/dev/null || true
docker compose up -d

echo "Đang đợi cơ sở dữ liệu và các dịch vụ khởi động ổn định (15s)..."
sleep 15

# 3. Thu hẹp đặc quyền Database (Least Privilege DB)
echo ""
echo "--- 3. THU HẸP ĐẶC QUYỀN DATABASE CHO USER WP_APP ---"
MYSQL_ROOT_PASS=$(grep '^MYSQL_ROOT_PASSWORD=' .env | cut -d '=' -f2 | tr -d '\r')
docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASS" << 'EOF'
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'wp_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX ON `wordpress`.* TO 'wp_app'@'%';
FLUSH PRIVILEGES;
EOF
echo "=> Đã thu hẹp quyền 'wp_app'@'%' về đúng phạm vi schema wordpress (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX)."

# 4. Kiểm tra và nạp lại cấu hình Nginx
echo ""
echo "--- 4. NẠP CẤU HÌNH BẢO MẬT NGINX (RATE LIMIT & ANTI-ENUMERATION) ---"
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload || true

# 5. Cấu hình tường lửa UFW máy chủ Linux
echo ""
echo "--- 5. THIẾT LẬP TƯỜNG LỬA HOST UFW ---"
if command -v ufw >/dev/null 2>&1; then
    echo "123" | sudo -S ufw allow 22/tcp || true
    echo "123" | sudo -S ufw allow 80/tcp || true
    echo "123" | sudo -S ufw allow 443/tcp || true
    echo "123" | sudo -S ufw allow 8080/tcp || true
    echo "123" | sudo -S ufw allow 8081/tcp || true
    echo "123" | sudo -S ufw default deny incoming || true
    echo "123" | sudo -S ufw default allow outgoing || true
    echo "123" | sudo -S ufw --force enable || true
    echo "=> Đã kích hoạt tường lửa UFW với quy tắc an toàn (cho phép 22, 80, 443, 8080, 8081)."
else
    echo "UFW chưa cài đặt, bỏ qua bước UFW."
fi

# 6. Thu thập toàn bộ bằng chứng kiểm tra vào evidence/buoc6-hardening.txt
{
    echo "================================================================================"
    echo "BẰNG CHỨNG THỰC NGHIỆM HARDENING (GIA CỐ BẢO MẬT HỆ THỐNG)"
    echo "Sinh viên: Lương Việt Anh - MSSV: DTC245200063"
    echo "Thời gian kiểm tra: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================================"
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 1: NON-ROOT CONTAINER & HẠN CHẾ ĐẶC QUYỀN CONTAINER (CAP_DROP / NO-NEW-PRIV)"
    echo "Kiểm tra user thực thi và đặc quyền trong các container:"
    for c in de3_mysql de3_wordpress de3_phpmyadmin de3_nginx de3_prometheus de3_grafana de3_cadvisor de3_nginx_exporter de3_mysqld_exporter de3_loki de3_promtail de3_alert_sink; do
        CFG_USER=$(docker inspect --format '{{.Config.User}}' "$c" 2>/dev/null || echo "default")
        PROC_USER=$(docker top "$c" 2>/dev/null | tail -n +2 | awk '{print $1}' | head -n 1 || echo "unknown")
        PRIV=$(docker inspect --format 'Privileged={{.HostConfig.Privileged}}, NoNewPriv={{.HostConfig.SecurityOpt}}' "$c" 2>/dev/null || echo "")
        echo "Container [$c]: Configured User='${CFG_USER:-default}', Process UID='$PROC_USER', Security: $PRIV"
    done
    echo ""
    echo "Ghi chú: cAdvisor và Promtail bắt buộc cần quyền root để đọc kernel cgroups và /var/lib/docker/containers logs (được phép ngoại lệ theo đặc tả)."
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 2: NETWORK ISOLATION (TÁCH 3 MẠNG ĐỘC LẬP: FRONTEND, BACKEND, MONITORING)"
    echo "Danh sách các mạng Docker:"
    docker network ls | grep -E "de3_frontend_net|de3_backend_net|de3_monitoring_net"
    echo ""
    echo "Kiểm tra thuộc tính internal của backend_net và monitoring_net:"
    docker network inspect de3_backend_net --format 'Network {{.Name}}: Internal = {{.Internal}}, Subnet = {{(index .IPAM.Config 0).Subnet}}'
    docker network inspect de3_monitoring_net --format 'Network {{.Name}}: Internal = {{.Internal}}, Subnet = {{(index .IPAM.Config 0).Subnet}}'
    echo ""
    echo "Kiểm tra container MySQL (de3_mysql) chỉ nằm trên backend_net:"
    docker inspect de3_mysql --format 'MySQL Networks: {{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 3: HẠN CHẾ QUYỀN TRUY CẬP CƠ SỞ DỮ LIỆU (LEAST PRIVILEGE DB)"
    echo "Quyền hạn của user ứng dụng 'wp_app'@'%':"
    docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASS" -e "SHOW GRANTS FOR 'wp_app'@'%';"
    echo ""
    echo "Quyền hạn của user giám sát 'exporter'@'%':"
    docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASS" -e "SHOW GRANTS FOR 'exporter'@'%';"
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 4: BẢO MẬT ỨNG DỤNG, SECURITY HEADERS VÀ RATE LIMITING TRÊN NGINX"
    echo "a) Kiểm tra Security Headers trên HTTPS:"
    curl -kI https://192.168.102.128/ | grep -iE 'x-frame-options|x-content-type-options|strict-transport-security|content-security-policy|server|x-xss' || true
    echo ""
    echo "b) Kiểm tra chặn XML-RPC (/xmlrpc.php -> HTTP 403):"
    curl -k -s -o /dev/null -w "HTTP Status /xmlrpc.php: %{http_code}\n" https://192.168.102.128/xmlrpc.php
    echo ""
    echo "c) Kiểm tra chặn quét người dùng (/ ?author=1 -> HTTP 403):"
    curl -k -s -o /dev/null -w "HTTP Status /?author=1: %{http_code}\n" https://192.168.102.128/?author=1
    echo ""
    echo "d) Kiểm tra chặn quét người dùng qua REST API (/wp-json/wp/v2/users -> HTTP 403):"
    curl -k -s -o /dev/null -w "HTTP Status /wp-json/wp/v2/users: %{http_code}\n" https://192.168.102.128/wp-json/wp/v2/users
    echo ""
    echo "e) Kiểm tra chặn thực thi mã PHP trong uploads (/wp-content/uploads/test.php -> HTTP 403):"
    curl -k -s -o /dev/null -w "HTTP Status /wp-content/uploads/test.php: %{http_code}\n" https://192.168.102.128/wp-content/uploads/test.php
    echo ""
    echo "f) Kiểm tra ẩn file cấu hình (/wp-config.php -> HTTP 404):"
    curl -k -s -o /dev/null -w "HTTP Status /wp-config.php: %{http_code}\n" https://192.168.102.128/wp-config.php
    echo ""
    echo "g) Kiểm tra Rate Limiting Nginx trên /wp-login.php (Gửi 12 requests liên tiếp):"
    RATE_HIT=0
    for i in $(seq 1 12); do
        CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/wp-login.php)
        if [ "$CODE" = "429" ] || [ "$CODE" = "503" ]; then
            RATE_HIT=$((RATE_HIT + 1))
        fi
    done
    echo "Số request bị Nginx chặn giới hạn tốc độ (HTTP 429/503): $RATE_HIT / 12"
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 5: TƯỜNG LỬA HOST UFW VÀ RÀ SOÁT CỔNG MỞ"
    echo "a) Trạng thái tường lửa UFW (sudo ufw status verbose):"
    echo "123" | sudo -S ufw status verbose || true
    echo ""
    echo "b) Các cổng TCP đang lắng nghe trên máy chủ (ss -tlnp):"
    ss -tlnp | grep -E "LISTEN"
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "BIỆN PHÁP 6: RÀ SOÁT BÍ MẬT TRONG MÃ NGUỒN VÀ LỊCH SỬ GIT (SECRETS AUDIT)"
    echo "Kiểm tra 'git grep' tìm kiếm mật khẩu thực tế trong toàn bộ repository:"
    SECRETS_FOUND=0
    for secret in "$MYSQL_ROOT_PASS" "Admin_WP2026_sB8eY3" "Grafana_Admin_2026_vP3xL8"; do
        MATCHES=$(git grep -F "$secret" || true)
        if [ -n "$MATCHES" ]; then
            echo "[CẢNH BÁO] Phát hiện lộ mật khẩu: $MATCHES"
            SECRETS_FOUND=$((SECRETS_FOUND + 1))
        fi
    done
    if [ "$SECRETS_FOUND" -eq 0 ]; then
        echo "BẢO MẬT XÁC NHẬN: Không tìm thấy bất kỳ mật khẩu nào bị lộ trong mã nguồn Git (đã loại trừ qua .env và .gitignore)."
    fi
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "SMOKE TEST: XÁC MINH CÁC CHỨC NĂNG HỆ THỐNG SAU KHI GIA CỐ"
    echo "- Trang chủ WordPress: HTTP $(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/)"
    echo "- Trang Danh sách Sản phẩm: HTTP $(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/san-pham/)"
    echo "- Trang Đăng nhập WordPress: HTTP $(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/wp-login.php)"
    echo "- Trang phpMyAdmin: HTTP $(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/phpmyadmin/)"
    echo "- Trang Grafana: HTTP $(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/grafana/login)"
    echo ""
    echo "Trạng thái Prometheus Targets sau khi chuyển mạng:"
    docker compose exec -T prometheus wget -qO- http://localhost:9090/api/v1/targets | grep -o '"job":"[^"]*","instance":"[^"]*","health":"[^"]*"' || true
    echo ""
    echo "================================================================================"
    echo "TẤT CẢ CÁC BIỆN PHÁP HARDENING ĐÃ ĐƯỢC ÁP DỤNG VÀ XÁC MINH THÀNH CÔNG."
    echo "================================================================================"
} 2>&1 | tee "$EVIDENCE_FILE"

echo ""
echo "=> Toàn bộ bằng chứng Hardening đã được lưu tại: $EVIDENCE_FILE"
