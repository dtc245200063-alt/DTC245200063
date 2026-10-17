#!/bin/bash
set -e

PROJECT_DIR="$HOME/De3_DTC245200063"
EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc3-nginx.txt"
cd "$PROJECT_DIR"

echo "=== 1. GENERATING SSL SELF-SIGNED CERTIFICATE ==="
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh 192.168.102.128

echo "=== 2. UPDATING WORDPRESS SITEURL AND HOME TO HTTPS ==="
docker compose run --rm wpcli option update home 'https://192.168.102.128'
docker compose run --rm wpcli option update siteurl 'https://192.168.102.128'
docker compose run --rm wpcli search-replace 'http://192.168.102.128:8080' 'https://192.168.102.128' --all-tables 2>/dev/null || true
docker compose run --rm wpcli search-replace 'http://localhost:8080' 'https://192.168.102.128' --all-tables 2>/dev/null || true
docker compose run --rm wpcli rewrite flush

echo "=== 3. STARTING / RESTARTING SERVICES WITH NGINX ==="
docker compose up -d --remove-orphans

echo "Waiting for services to be ready..."
sleep 4

echo "=== 4. TESTING NGINX CONFIGURATION SYNTAX ==="
docker compose exec -T nginx nginx -t

echo "=== 5. TESTING HTTP (PORT 80) 301 REDIRECT TO HTTPS ==="
HTTP_REDIRECT=$(curl -s -I http://192.168.102.128 | grep -E "HTTP/|Location:")
echo "$HTTP_REDIRECT"

echo "=== 6. TESTING HTTPS (PORT 443) AND SECURITY HEADERS ==="
SECURITY_HEADERS=$(curl -k -I https://192.168.102.128)
echo "$SECURITY_HEADERS"

echo "=== 7. TESTING ACCESS TO ENDPOINTS VIA HTTPS ==="
echo -n "Trang chủ WordPress (https://localhost/): HTTP "
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost/

echo -n "Trang phpMyAdmin (https://localhost/phpmyadmin/): HTTP "
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost/phpmyadmin/

echo -n "Chặn truy cập /xmlrpc.php (https://localhost/xmlrpc.php): HTTP "
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost/xmlrpc.php

echo -n "Chặn truy cập file ẩn .env (https://localhost/.env): HTTP "
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost/.env

echo -n "Chặn truy cập wp-config.php (https://localhost/wp-config.php): HTTP "
curl -k -s -o /dev/null -w "%{http_code}\n" https://localhost/wp-config.php

echo "=== 8. VERIFYING PORTS 8080 & 8081 ARE NO LONGER PUBLISHED ==="
echo "Checking open listening ports on host (ss -tlnp | grep -E '8080|8081'):"
ss -tlnp | grep -E '8080|8081' || echo "=> ĐÃ GỠ THÀNH CÔNG: Cổng 8080 và 8081 không còn lắng nghe từ bên ngoài!"

echo "=== 9. TESTING HTTPS WP-LOGIN AUTHENTICATION VIA PROXY ==="
WP_ADMIN_PASS=$(grep '^WP_ADMIN_PASSWORD=' .env | cut -d '=' -f2)

# Successful login test via HTTPS proxy
curl -k -s -L -c /tmp/wp_https_cookie.txt \
     -d "log=quantri&pwd=${WP_ADMIN_PASS}&wp-submit=Log+In&testcookie=1" \
     -b "wordpress_test_cookie=WP+Cookie+check" \
     https://192.168.102.128/wp-login.php > /dev/null || true

ADMIN_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" -b /tmp/wp_https_cookie.txt https://192.168.102.128/wp-admin/)
echo "Truy cập /wp-admin/ qua HTTPS session cookie: HTTP $ADMIN_STATUS"

echo "=== 10. CHECKING CLIENT IP FORWARDING IN WORDPRESS LOGS ==="
echo "Last 5 lines of WordPress security log:"
docker logs de3_wordpress 2>&1 | grep "LOGIN_" | tail -n 5 || true

echo "=== 11. RECORDING EVIDENCE TO $EVIDENCE_FILE ==="
mkdir -p "$PROJECT_DIR/evidence"

{
    echo "=================================================="
    echo "EVIDENCE BƯỚC 3: NGINX REVERSE PROXY & HTTPS TỰ KÝ"
    echo "Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sinh viên: Lương Việt Anh - DTC245200063"
    echo "=================================================="
    echo ""
    echo "1. CẤU HÌNH NGINX SYNTAX (nginx -t):"
    docker compose exec -T nginx nginx -t
    echo ""
    echo "2. THÔNG TIN CHỨNG CHỈ SSL TỰ KÝ (SAN IP:192.168.102.128):"
    openssl s_client -connect localhost:443 </dev/null 2>/dev/null | openssl x509 -noout -subject -dates -ext subjectAltName
    echo ""
    echo "3. KIỂM TRA CHUYỂN HƯỚNG HTTP 80 -> HTTPS 443 (301 REDIRECT):"
    curl -s -I http://192.168.102.128
    echo ""
    echo "4. KIỂM TRA HTTPS VÀ TOÀN BỘ SECURITY HEADERS (curl -kI):"
    curl -k -I https://192.168.102.128
    echo ""
    echo "5. TRẠNG THÁI CÁC ENDPOINT VÀ BẢO MẬT ĐƯỜNG DẪN NHẠY CẢM:"
    echo -n "Trang chủ WordPress: "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/
    echo -n "phpMyAdmin (/phpmyadmin/): "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/phpmyadmin/
    echo -n "Chặn /xmlrpc.php: "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/xmlrpc.php
    echo -n "Chặn file ẩn (.env): "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/.env
    echo -n "Chặn file cấu hình (wp-config.php): "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/wp-config.php
    echo -n "Trang trạng thái Nginx (/nginx_status cho nội bộ): "
    curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://localhost/nginx_status
    echo ""
    echo "6. XÁC NHẬN GỠ CỔNG TRỰC TIẾP (8080, 8081):"
    ss -tlnp | grep -E '8080|8081' || echo "Cổng 8080 và 8081 đã được gỡ hoàn toàn khỏi máy host."
    echo ""
    echo "7. TRẠNG THÁI CÁC CONTAINER HIỆN TẠI (docker compose ps):"
    docker compose ps
    echo ""
    echo "8. ĐĂNG NHẬP THỬ QUA HTTPS PROXY & FORWARD REAL IP:"
    echo "HTTP Status /wp-admin/: $ADMIN_STATUS"
    docker logs de3_wordpress 2>&1 | grep "LOGIN_" | tail -n 5
} > "$EVIDENCE_FILE"

cat "$EVIDENCE_FILE"
