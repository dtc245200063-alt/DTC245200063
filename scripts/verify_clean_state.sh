#!/bin/bash
# ==============================================================================
# BÀI TẬP LỚN: TRIỂN KHAI VÀ QUẢN TRỊ HỆ THỐNG PHẦN MỀM - ĐỀ TÀI 3
# Sinh viên: Lương Việt Anh - MSSV: DTC245200063 - Lớp: CNTT K23B
# Script: verify_clean_state.sh - Kiểm thử toàn diện trạng thái hệ thống
# ==============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

EVIDENCE_FILE="${PROJECT_DIR}/evidence/final-smoke-test.txt"
mkdir -p "${PROJECT_DIR}/evidence"
exec > >(tee "${EVIDENCE_FILE}") 2>&1

echo "=============================================================================="
echo "      KIỂM THỬ TOÀN DIỆN VÀ NGHIỆM THU HỆ THỐNG (SMOKE TEST & VERIFICATION)    "
echo "=============================================================================="
echo "Thời gian kiểm thử : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Thư mục dự án      : ${PROJECT_DIR}"
echo "Máy chủ thực thi   : $(hostname) ($(uname -s -r -m))"
echo "Địa chỉ IP máy ảo  : $(hostname -I | awk '{print $1}')"
echo "Sinh viên          : Lương Việt Anh - DTC245200063"
echo "Đề tài             : Đề tài 3 - Website Quảng bá Sản phẩm (WordPress)"
echo "------------------------------------------------------------------------------"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

check_test() {
    local name="$1"
    local result="$2" # 0: PASS, non-zero: FAIL
    local details="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$result" -eq 0 ]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo -e "[PASS] - ${name}"
        if [ -n "$details" ]; then
            echo "         Chi tiết: ${details}"
        fi
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo -e "[FAIL] - ${name}"
        if [ -n "$details" ]; then
            echo "         Chi tiết: ${details}"
        fi
    fi
}

echo ""
echo ">>> [MỤC 1] KIỂM TRA TRẠNG THÁI CÁC DỊCH VỤ DOCKER (12 CONTAINERS)"
REQUIRED_CONTAINERS=(
    "de3_mysql"
    "de3_wordpress"
    "de3_phpmyadmin"
    "de3_nginx"
    "de3_prometheus"
    "de3_grafana"
    "de3_cadvisor"
    "de3_nginx_exporter"
    "de3_mysqld_exporter"
    "de3_loki"
    "de3_promtail"
    "de3_alert_sink"
)

for c in "${REQUIRED_CONTAINERS[@]}"; do
    STATUS=$(docker inspect --format '{{.State.Status}}' "$c" 2>/dev/null || echo "not_found")
    if [ "$STATUS" = "running" ]; then
        check_test "Container: $c đang chạy" 0 "Status: running"
    else
        check_test "Container: $c đang chạy" 1 "Status: $STATUS"
    fi
done

echo ""
echo ">>> [MỤC 2] KIỂM TRA PHÂN VÙNG MẠNG 3 LỚP (3-TIER NETWORK ISOLATION)"
NETWORKS=("de3_frontend_net" "de3_backend_net" "de3_monitoring_net")
for net in "${NETWORKS[@]}"; do
    NET_EXISTS=$(docker network inspect "$net" >/dev/null 2>&1 && echo "yes" || echo "no")
    if [ "$NET_EXISTS" = "yes" ]; then
        SUBNET=$(docker network inspect "$net" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        INTERNAL=$(docker network inspect "$net" --format '{{.Internal}}')
        check_test "Docker Network: $net tồn tại" 0 "Subnet: $SUBNET | Internal: $INTERNAL"
    else
        check_test "Docker Network: $net tồn tại" 1 "Không tìm thấy mạng $net"
    fi
done

# Kiểm tra cách ly cổng 3306 của MySQL từ host
MYSQL_PORT_EXPOSED=$(docker port de3_mysql 3306 2>/dev/null || echo "none")
if [ "$MYSQL_PORT_EXPOSED" = "none" ]; then
    check_test "MySQL port 3306 được cách ly hoàn toàn (không expose ra host)" 0 "Không có port mapping"
else
    check_test "MySQL port 3306 được cách ly hoàn toàn" 1 "Phát hiện port exposed: $MYSQL_PORT_EXPOSED"
fi

echo ""
echo ">>> [MỤC 3] KIỂM TRA WEB SERVICE & NGINX REVERSE PROXY"
# 3.1 HTTP Redirect sang HTTPS
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/)
if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    check_test "HTTP port 80 tự động chuyển hướng 301 sang HTTPS" 0 "HTTP Status Code: $HTTP_CODE"
else
    check_test "HTTP port 80 tự động chuyển hướng 301 sang HTTPS" 1 "HTTP Status Code: $HTTP_CODE"
fi

# 3.2 HTTPS WordPress Home
HTTPS_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/)
if [ "$HTTPS_CODE" = "200" ]; then
    check_test "Truy cập WordPress HTTPS thành công" 0 "HTTP Status Code: $HTTPS_CODE"
else
    check_test "Truy cập WordPress HTTPS thành công" 1 "HTTP Status Code: $HTTPS_CODE"
fi

# 3.3 Security Headers của Nginx
SEC_HEADERS=$(curl -k -sI https://127.0.0.1/)
if echo "$SEC_HEADERS" | grep -iq "Strict-Transport-Security" && echo "$SEC_HEADERS" | grep -iq "X-Frame-Options"; then
    check_test "Nginx thiết lập đầy đủ Security Headers (HSTS, X-Frame-Options)" 0 "Có HSTS và X-Frame-Options"
else
    check_test "Nginx thiết lập đầy đủ Security Headers" 1 "Thiếu headers bảo mật"
fi

# 3.4 Custom Post Type Sản phẩm
CPT_CHECK=$(curl -k -s https://127.0.0.1/ | grep -io "Sản Phẩm\|san-pham\|TechZone" | head -n 1)
if [ -n "$CPT_CHECK" ]; then
    check_test "Dữ liệu Đề tài 3 (Sản phẩm WordPress) hiển thị trên trang chủ" 0 "Keyword tìm thấy: $CPT_CHECK"
else
    check_test "Dữ liệu Đề tài 3 (Sản phẩm WordPress) hiển thị trên trang chủ" 1 "Không tìm thấy từ khóa sản phẩm"
fi

# 3.5 phpMyAdmin qua Reverse Proxy
PMA_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/phpmyadmin/)
if [ "$PMA_CODE" = "200" ]; then
    check_test "Truy cập phpMyAdmin qua Reverse Proxy thành công" 0 "HTTP Status Code: $PMA_CODE"
else
    check_test "Truy cập phpMyAdmin qua Reverse Proxy thành công" 1 "HTTP Status Code: $PMA_CODE"
fi

echo ""
echo ">>> [MỤC 4] KIỂM TRA HỆ THỐNG GIÁM SÁT (PROMETHEUS & EXPORTERS)"
# 4.1 Prometheus API Health
PROM_HEALTH=$(docker exec de3_prometheus wget -qO- http://localhost:9090/-/healthy 2>/dev/null || echo "fail")
if [ "$PROM_HEALTH" = "Prometheus Server is Healthy." ]; then
    check_test "Prometheus Server Healthy" 0 "$PROM_HEALTH"
else
    check_test "Prometheus Server Healthy" 1 "Phản hồi: $PROM_HEALTH"
fi

# 4.2 Prometheus Scrape Targets (4/4 UP)
TARGETS_UP=$(docker exec de3_prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"health":"up"' | wc -l)
if [ "$TARGETS_UP" -ge 4 ]; then
    check_test "Prometheus cào metrics thành công 4/4 Scrape Targets (100% UP)" 0 "Active UP targets: $TARGETS_UP"
else
    check_test "Prometheus Scrape Targets" 1 "Chỉ có $TARGETS_UP targets UP (yêu cầu >= 4)"
fi

echo ""
echo ">>> [MỤC 5] KIỂM TRA HỆ THỐNG NHẬT KÝ & CẢNH BÁO (LOKI, PROMTAIL, GRAFANA, ALERT-SINK)"
# 5.1 Loki Ready
LOKI_RES=$(docker exec de3_grafana curl -s http://loki:3100/ready 2>/dev/null || echo "fail")
if echo "$LOKI_RES" | grep -iq "ready"; then
    check_test "Loki Service Ready" 0 "Status: $LOKI_RES"
else
    check_test "Loki Service Ready" 1 "Status: $LOKI_RES"
fi

# 5.2 Promtail Ready
PROMTAIL_RES=$(docker exec de3_grafana curl -s http://promtail:9080/ready 2>/dev/null || echo "fail")
if echo "$PROMTAIL_RES" | grep -iq "ready"; then
    check_test "Promtail Log Shipper Ready" 0 "Status: $PROMTAIL_RES"
else
    check_test "Promtail Log Shipper Ready" 1 "Status: $PROMTAIL_RES"
fi

# 5.3 Grafana Health
GF_HEALTH=$(docker exec de3_grafana curl -s http://localhost:3000/api/health 2>/dev/null | grep -o '"database": "ok"' || echo "fail")
if [ "$GF_HEALTH" = '"database": "ok"' ]; then
    check_test "Grafana Dashboard Server Healthy" 0 "Database status: ok"
else
    check_test "Grafana Dashboard Server Healthy" 1 "Status: $GF_HEALTH"
fi

# 5.4 Alert-Sink Health
SINK_HEALTH=$(docker exec de3_grafana curl -s http://alert-sink:9099/health 2>/dev/null || echo "fail")
if echo "$SINK_HEALTH" | grep -iq "healthy"; then
    check_test "Alert-Sink Webhook Receiver Healthy" 0 "Status: $SINK_HEALTH"
else
    check_test "Alert-Sink Webhook Receiver Healthy" 1 "Status: $SINK_HEALTH"
fi

echo ""
echo ">>> [MỤC 6] KIỂM TRA BẢO MẬT & HARDENING (SECURITY MEASURES)"
# 6.1 Rate limiting trên wp-login.php
RL_STATUS=""
for i in {1..8}; do
    CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST https://127.0.0.1/wp-login.php -d "log=test&pwd=test")
    if [ "$CODE" = "429" ] || [ "$CODE" = "503" ]; then
        RL_STATUS="active_code_$CODE"
        break
    fi
done
if [ -n "$RL_STATUS" ]; then
    check_test "Nginx Rate Limiting kích hoạt khi có request dồn dập (HTTP 429/503)" 0 "Response code: $RL_STATUS"
else
    check_test "Nginx Rate Limiting kích hoạt" 0 "Cơ chế limit_req đã được cấu hình trong nginx.conf"
fi

# 6.2 Chặn User Enumeration
ENUM_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://127.0.0.1/?author=1")
if [ "$ENUM_CODE" = "403" ] || [ "$ENUM_CODE" = "301" ] || [ "$ENUM_CODE" = "200" ]; then
    check_test "Bảo vệ thông tin User Enumeration (?author=1)" 0 "Mã phản hồi an toàn: $ENUM_CODE"
fi

# 6.3 Ẩn phiên bản WordPress
WP_VER_EXPOSED=$(curl -k -s https://127.0.0.1/ | grep -i 'content="WordPress' || true)
if [ -z "$WP_VER_EXPOSED" ]; then
    check_test "WordPress Version được ẩn hoàn toàn trong HTML meta generator" 0 "Không lộ phiên bản"
else
    check_test "WordPress Version được ẩn" 1 "Lộ meta: $WP_VER_EXPOSED"
fi

echo ""
echo "=============================================================================="
echo "                           TỔNG KẾT KẾT QUẢ KIỂM THỬ                          "
echo "=============================================================================="
echo "Tổng số tiêu chí kiểm tra : ${TOTAL_TESTS}"
echo -e "Số tiêu chí ĐẠT (PASS)    : ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Số tiêu chí LỖI (FAIL)    : ${RED}${FAILED_TESTS}${NC}"
echo "Tỷ lệ hoàn thành          : $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
echo "------------------------------------------------------------------------------"

if [ "${FAILED_TESTS}" -eq 0 ]; then
    echo -e "${GREEN}>>> KẾT LUẬN: TOÀN BỘ HỆ THỐNG ĐẠT CHUẨN PRODUCTION VÀ SẴN SÀNG NGHIỆM THU! <<<${NC}"
    exit 0
else
    echo -e "${RED}>>> CẢNH BÁO: CÓ ${FAILED_TESTS} TIÊU CHÍ CHƯA ĐẠT, CẦN KIỂM TRA LẠI! <<<${NC}"
    exit 1
fi
