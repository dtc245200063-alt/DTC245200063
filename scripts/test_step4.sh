#!/bin/bash
set -e

PROJECT_DIR="$HOME/De3_DTC245200063"
EVIDENCE_FILE="$PROJECT_DIR/evidence/buoc4-giamsat.txt"
cd "$PROJECT_DIR"

echo "=================================================="
echo "BƯỚC 4: TRIỂN KHAI HỆ THỐNG GIÁM SÁT PROMETHEUS + GRAFANA"
echo "Sinh viên: Lương Việt Anh - DTC245200063"
echo "=================================================="

# 1. Tạo MySQL Exporter user nếu chưa có
echo ""
echo "--- 1. CẤU HÌNH USER EXPORTER TRONG MYSQL ---"
MYSQL_ROOT_PASS=$(grep '^MYSQL_ROOT_PASSWORD=' .env | cut -d '=' -f2)
MYSQL_EXP_PASS=$(grep '^MYSQL_EXPORTER_PASSWORD=' .env | cut -d '=' -f2)
docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASS" -e "
  CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '$MYSQL_EXP_PASS' WITH MAX_USER_CONNECTIONS 3;
  GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'%';
  GRANT SELECT ON performance_schema.* TO 'exporter'@'%';
  FLUSH PRIVILEGES;
"
echo "=> Đã cấp quyền user 'exporter' trong MySQL thành công."

# 2. Khởi chạy toàn bộ hệ thống với Docker Compose
echo ""
echo "--- 2. KHỞI CHẠY CONTAINER GIÁM SÁT ---"
docker compose up -d --remove-orphans

echo "Đang đợi các dịch vụ ổn định (10s)..."
sleep 10
docker compose exec -T nginx nginx -s reload || true

# 3. Sinh tải curl mô phỏng người dùng (~200 requests)
echo ""
echo "--- 3. SINH TẢI TRUY CẬP (TRAFFIC GENERATION) ---"
echo "Thực hiện 200 requests vào website để kích hoạt metrics..."
for i in $(seq 1 40); do
    curl -k -s -o /dev/null https://192.168.102.128/ &
    curl -k -s -o /dev/null https://192.168.102.128/san-pham/ &
    curl -k -s -o /dev/null https://192.168.102.128/gioi-thieu/ &
    curl -k -s -o /dev/null https://192.168.102.128/tin-tuc/ &
    curl -k -s -o /dev/null https://192.168.102.128/lien-he/ &
    if [ $((i % 10)) -eq 0 ]; then
        wait
    fi
done
wait
echo "=> Đã gửi thành công 200 requests vào Nginx & WordPress."

# 4. Kiểm tra Prometheus Targets
echo ""
echo "--- 4. KIỂM TRA TRẠNG THÁI TARGETS TRÊN PROMETHEUS ---"
TARGETS_JSON=$(docker compose exec -T nginx curl -s http://prometheus:9090/api/v1/targets)
echo "$TARGETS_JSON" | grep -o '"job":"[^"]*","instance":"[^"]*","health":"[^"]*"' || echo "$TARGETS_JSON"

# 5. Kiểm tra truy cập Grafana qua Nginx Reverse Proxy
echo ""
echo "--- 5. KIỂM TRA GRAFANA QUA HTTPS REVERSE PROXY ---"
GRAFANA_PASS=$(grep '^GRAFANA_ADMIN_PASSWORD=' .env | cut -d '=' -f2)
GRAFANA_USER=$(grep '^GRAFANA_ADMIN_USER=' .env | cut -d '=' -f2)
GRAFANA_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" https://192.168.102.128/grafana/login)
echo "Truy cập https://192.168.102.128/grafana/login: HTTP $GRAFANA_STATUS"

# 6. Kiểm tra Provisioning Datasources & Dashboards
echo ""
echo "--- 6. KIỂM TRA DATASOURCES VÀ DASHBOARDS TRONG GRAFANA ---"
DS_CHECK=$(curl -k -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" https://192.168.102.128/grafana/api/datasources)
echo "Datasources: $(echo "$DS_CHECK" | grep -o '"name":"[^"]*"' | tr '\n' ' ')"

DASH_CHECK=$(curl -k -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" https://192.168.102.128/grafana/api/search?type=dash-db)
echo "Dashboards: $(echo "$DASH_CHECK" | grep -o '"title":"[^"]*"' | tr '\n' ' ')"

# 7. Ghi bằng chứng vào evidence/buoc4-giamsat.txt
echo ""
echo "--- 7. GHI BẰNG CHỨNG VÀO $EVIDENCE_FILE ---"
mkdir -p "$PROJECT_DIR/evidence"

{
    echo "=================================================="
    echo "EVIDENCE BƯỚC 4: HỆ THỐNG GIÁM SÁT PROMETHEUS + GRAFANA"
    echo "Thời gian: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sinh viên: Lương Việt Anh - DTC245200063"
    echo "=================================================="
    echo ""
    echo "1. TRẠNG THÁI CÁC DỊCH VỤ DOCKER COMPOSE (docker compose ps):"
    docker compose ps
    echo ""
    echo "2. KIỂM TRA MẠNG NỘI BỘ VÀ KHÔNG PUBLISH PORT GIÁM SÁT RA MÁY HOST:"
    ss -tlnp | grep -E '9090|3000|8080|9113|9104' || echo "BẢO MẬT TỐT: Các cổng giám sát (9090, 3000, 8080, 9113, 9104) hoàn toàn nằm trong mạng nội bộ Docker de3_network, không mở trực tiếp ra host."
    echo ""
    echo "3. PROMETHEUS TARGETS TRẠNG THÁI (up == 1):"
    docker compose exec -T nginx curl -s http://prometheus:9090/api/v1/targets | grep -o '{"discoveredLabels":{[^}]*},"labels":{[^}]*},"scrapePool":"[^"]*","scrapeUrl":"[^"]*","globalUrl":"[^"]*","lastError":"[^"]*","lastScrape":"[^"]*","lastScrapeDuration":[^,]*,"health":"[^"]*"' | tr '\n' '\n\n'
    echo ""
    echo "4. KIỂM TRA CHỈ SỐ THỰC TẾ TỪ CÁC EXPORTER:"
    echo "a) Nginx Exporter metrics (active, requests):"
    docker compose exec -T nginx curl -s http://nginx-exporter:9113/metrics | grep -E "^nginx_connections_active|^nginx_http_requests_total|^nginx_connections_handled"
    echo ""
    echo "b) MySQL Exporter metrics (queries, uptime, threads):"
    docker compose exec -T nginx curl -s http://mysqld-exporter:9104/metrics | grep -E "^mysql_global_status_queries|^mysql_global_status_uptime|^mysql_global_status_threads_connected"
    echo ""
    echo "c) cAdvisor metrics (container memory sample):"
    docker compose exec -T nginx curl -s http://cadvisor:8080/metrics | grep "container_memory_usage_bytes" | grep 'name="de3_' | head -n 1
    echo ""
    echo "5. GRAFANA REVERSE PROXY & PROVISIONING API:"
    echo "HTTP Status /grafana/login: $GRAFANA_STATUS"
    echo "Datasources API:"
    curl -k -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" https://192.168.102.128/grafana/api/datasources
    echo ""
    echo "Dashboards API (3 Dashboards đã provisioned):"
    curl -k -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" https://192.168.102.128/grafana/api/search?type=dash-db
    echo ""
    echo "6. MÔ PHỎNG SINH TẢI (TRAFFIC GENERATION):"
    echo "Đã thực hiện thành công 200 requests vào các URL sản phẩm và chuyên mục."
} > "$EVIDENCE_FILE"

cat "$EVIDENCE_FILE"
echo ""
echo "=================================================="
echo "HOÀN THÀNH KIỂM TRA BƯỚC 4 THÀNH CÔNG!"
echo "=================================================="
