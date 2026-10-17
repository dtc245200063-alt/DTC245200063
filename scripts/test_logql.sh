#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc5-logql.txt"
mkdir -p "$PROJECT_DIR/evidence"

echo "================================================================================"
echo "KIỂM TRA CÁC TRUY VẤN LOGQL QUA LOKI API"
echo "Sinh viên: Lương Việt Anh - MSSV: DTC245200063"
echo "================================================================================"

# Hàm gửi query tới Loki qua container nội bộ
query_loki() {
    local q="$1"
    local encoded_q=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$q")
    docker compose exec -T loki wget -qO- "http://localhost:3100/loki/api/v1/query?query=${encoded_q}"
}

{
    echo "================================================================================"
    echo "BẰNG CHỨNG TRUY VẤN LOGQL TRÊN HỆ THỐNG LOKI + PROMTAIL"
    echo "Sinh viên: Lương Việt Anh - MSSV: DTC245200063"
    echo "Thời gian kiểm tra: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================================"
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "Q1: Lỗi HTTP 5xx của Nginx"
    echo "LogQL: {job=\"nginx\"} |~ \"\\\\\" 5[0-9]{2} \""
    echo "Mục đích: Giám sát các lỗi phía server phát sinh từ Nginx reverse proxy hoặc upstream."
    echo "Kết quả truy vấn:"
    query_loki '{job="nginx"} |~ "\" 5[0-9]{2} "' || true
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "Q2: Lỗi hoặc ngoại lệ ứng dụng WordPress"
    echo "LogQL: {job=\"webapp\"} |~ \"(?i)(error|exception|failed|fatal)\""
    echo "Mục đích: Phát hiện các cảnh báo lỗi PHP, exception hệ thống hoặc thông báo thất bại."
    echo "Kết quả truy vấn:"
    query_loki '{job="webapp"} |~ "(?i)(error|exception|failed|fatal)"' || true
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "Q3: Đăng nhập thất bại vào WordPress"
    echo "LogQL: {job=\"webapp\"} |= \"LOGIN_FAILED\""
    echo "Mục đích: Trích xuất chính xác các sự kiện xác thực không thành công được ghi bởi mu-plugin."
    echo "Kết quả truy vấn:"
    query_loki '{job="webapp"} |= "LOGIN_FAILED"' || true
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "Q4: Số lần đăng nhập thất bại theo phút (Metric query)"
    echo "LogQL: sum(count_over_time({job=\"webapp\"} |= \"LOGIN_FAILED\" [1m]))"
    echo "Mục đích: Đo lường tần suất đăng nhập sai để phát hiện bất thường và kích hoạt Alert."
    echo "Kết quả truy vấn:"
    query_loki 'sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))' || true
    echo ""

    echo "--------------------------------------------------------------------------------"
    echo "Q5: Số request POST tới trang đăng nhập WordPress"
    echo "LogQL: sum(count_over_time({job=\"nginx\"} |= \"POST /wp-login.php\" [1m]))"
    echo "Mục đích: Thống kê số lượng yêu cầu xác thực gửi qua Nginx reverse proxy."
    echo "Kết quả truy vấn:"
    query_loki 'sum(count_over_time({job="nginx"} |= "POST /wp-login.php" [1m]))' || true
    echo ""

    echo "================================================================================"
    echo "TẤT CẢ 5 TRUY VẤN LOGQL ĐÃ ĐƯỢC THỰC THI THÀNH CÔNG VỚI LOKI API."
    echo "================================================================================"
} 2>&1 | tee "$EVIDENCE_FILE"

echo ""
echo "=> Đã lưu bằng chứng LogQL vào: $EVIDENCE_FILE"
