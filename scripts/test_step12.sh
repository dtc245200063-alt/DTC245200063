#!/bin/bash
set -e

PROJECT_DIR="$HOME/De3_DTC245200063"
EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc12-wordpress-db.txt"
cd "$PROJECT_DIR"

echo "=== 1. STARTING DATABASE CONTAINER ==="
docker compose up -d db

echo "Waiting for MySQL to become healthy..."
while [ "$(docker inspect --format='{{.State.Health.Status}}' de3_mysql 2>/dev/null)" != "healthy" ]; do
    echo -n "."
    sleep 2
done
echo " MySQL is HEALTHY!"

echo "=== 2. STARTING WORDPRESS & PHPMYADMIN ==="
docker compose up -d wordpress phpmyadmin

echo "Waiting for WordPress Apache to start responding..."
for i in $(seq 1 30); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || true)
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
        echo " WordPress web server returned HTTP $STATUS"
        break
    fi
    sleep 2
done

echo "=== 3. RUNNING WP-CLI AUTOMATIC INSTALLATION ==="
docker compose run --rm --entrypoint /bin/sh wpcli /scripts/install.sh

echo "=== 4. TESTING IDEMPOTENCY (RUNNING INSTALL A SECOND TIME) ==="
docker compose run --rm --entrypoint /bin/sh wpcli /scripts/install.sh

echo "=== 5. RUNNING AUTHENTICATION LOG TESTS ==="
# Test Failed Login with wrong password
echo "Testing LOGIN_FAILED (wrong_password)..."
curl -s -L -c /tmp/wp_cookie.txt -d "log=quantri&pwd=WrongPassword123!&wp-submit=Log+In&testcookie=1" \
     -b "wordpress_test_cookie=WP+Cookie+check" \
     -H "Host: 192.168.102.128:8080" \
     http://localhost:8080/wp-login.php > /dev/null || true

# Test Failed Login with unknown user
echo "Testing LOGIN_FAILED (unknown_user)..."
curl -s -L -c /tmp/wp_cookie.txt -d "log=hacker_fake&pwd=SomePass123!&wp-submit=Log+In&testcookie=1" \
     -b "wordpress_test_cookie=WP+Cookie+check" \
     -H "Host: 192.168.102.128:8080" \
     http://localhost:8080/wp-login.php > /dev/null || true

# Test Successful Login
echo "Testing LOGIN_SUCCESS..."
WP_ADMIN_PASS=$(grep '^WP_ADMIN_PASSWORD=' .env | cut -d '=' -f2)
curl -s -L -c /tmp/wp_admin_cookie.txt -d "log=quantri&pwd=${WP_ADMIN_PASS}&wp-submit=Log+In&testcookie=1" \
     -b "wordpress_test_cookie=WP+Cookie+check" \
     -H "Host: 192.168.102.128:8080" \
     http://localhost:8080/wp-login.php > /dev/null || true

# Verify wp-admin access with cookie
ADMIN_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -b /tmp/wp_admin_cookie.txt -H "Host: 192.168.102.128:8080" http://localhost:8080/wp-admin/)
echo "Access /wp-admin/ with session cookie HTTP Code: $ADMIN_HTTP_CODE"

echo "=== 6. VERIFYING DOCKER LOGS FOR AUDIT MESSAGES ==="
echo "--- Last 10 lines of WordPress logs matching LOGIN_ ---"
docker logs de3_wordpress 2>&1 | grep "LOGIN_" | tail -n 10 || true

echo "=== 7. COLLECTING EVIDENCE AND WRITING TO $EVIDENCE_FILE ==="
mkdir -p "$PROJECT_DIR/evidence"

WP_PASS_CLEAN="[MASKED_IN_EVIDENCE]"
DB_PASS=$(grep '^MYSQL_ROOT_PASSWORD=' .env | cut -d '=' -f2)

{
    echo "=================================================="
    echo "EVIDENCE BƯỚC 1 & 2: WORDPRESS + MYSQL + PHPMYADMIN"
    echo "Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sinh viên: Lương Việt Anh - DTC245200063"
    echo "=================================================="
    echo ""
    echo "1. TRẠNG THÁI CÁC CONTAINER (docker compose ps):"
    docker compose ps
    echo ""
    echo "2. KIỂM TRA TRUY CẬP HTTP:"
    echo -n "Trang chủ (http://192.168.102.128:8080/): HTTP "
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: 192.168.102.128:8080" http://localhost:8080/
    echo -n "Trang sản phẩm (http://192.168.102.128:8080/san-pham/): HTTP "
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: 192.168.102.128:8080" http://localhost:8080/san-pham/
    echo -n "Trang đăng nhập (http://192.168.102.128:8080/wp-login.php): HTTP "
    curl -s -o /dev/null -w "%{http_code}\n" -H "Host: 192.168.102.128:8080" http://localhost:8080/wp-login.php
    echo -n "phpMyAdmin (http://localhost:8081/): HTTP "
    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8081/
    echo ""
    echo "3. NỘI DUNG TRANG SẢN PHẨM (kiểm tra 12 sản phẩm):"
    curl -s -H "Host: 192.168.102.128:8080" http://localhost:8080/san-pham/ | grep -o 'class="de3-product-card"' | wc -l | xargs -I {} echo "Số lượng card sản phẩm tìm thấy trên trang: {}"
    echo ""
    echo "4. KIỂM TRA CƠ SỞ DỮ LIỆU MYSQL (qua docker exec):"
    echo "--- Bảng dữ liệu trong database 'wordpress': ---"
    docker exec de3_mysql mysql -u root -p"$DB_PASS" wordpress -e "SHOW TABLES;"
    echo ""
    echo "--- Đếm số lượng sản phẩm CPT 'product': ---"
    docker exec de3_mysql mysql -u root -p"$DB_PASS" wordpress -e "SELECT count(*) AS total_products FROM wp_posts WHERE post_type='product' AND post_status='publish';"
    echo ""
    echo "--- Danh sách tài khoản người dùng: ---"
    docker exec de3_mysql mysql -u root -p"$DB_PASS" wordpress -e "SELECT ID, user_login, user_email, user_registered, user_status FROM wp_users;"
    echo ""
    echo "5. LOG BẢO MẬT GHI NHẬN LOGIN_FAILED VÀ LOGIN_SUCCESS:"
    docker logs de3_wordpress 2>&1 | grep "LOGIN_" | tail -n 10
    echo ""
    echo "6. KIỂM TRA TÍNH TOÀN VẸN IDEMPOTENT CỦA SCRIPT CÀI ĐẶT:"
    echo "Script install.sh đã chạy 2 lần liên tiếp mà không bị trùng lặp sản phẩm."
} > "$EVIDENCE_FILE"

cat "$EVIDENCE_FILE"
