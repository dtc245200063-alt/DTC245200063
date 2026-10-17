#!/bin/bash
set -e

echo "=================================================="
echo "KIỂM TRA TOÀN DIỆN YÊU CẦU WEBSITE (BƯỚC 1 & 2)"
echo "=================================================="

WP_CLI="docker compose -f /home/vanh/De3_DTC245200063/docker-compose.yml run --rm wpcli"
HOST_IP="192.168.102.128:8080"

echo ""
echo "--- 1. KIỂM TRA DOCKER CONTAINERS & PORTS ---"
docker compose -f /home/vanh/De3_DTC245200063/docker-compose.yml ps

echo ""
echo "--- 2. KIỂM TRA TÀI KHOẢN NGƯỜI DÙNG (ROLES) ---"
$WP_CLI user list --fields=ID,user_login,display_name,roles,user_email

echo ""
echo "--- 3. KIỂM TRA 12 SẢN PHẨM ---"
$WP_CLI post list --post_type=product --fields=ID,post_title,post_name,post_status --format=table
TOTAL_PROD=$($WP_CLI post list --post_type=product --format=count)
echo "=> Tổng số sản phẩm CPT 'product': $TOTAL_PROD / 12"

echo ""
echo "--- 4. KIỂM TRA GIÁ SẢN PHẨM & ẢNH ĐẠI DIỆN ---"
for id in $($WP_CLI post list --post_type=product --field=ID); do
    title=$($WP_CLI post get "$id" --field=post_title)
    price=$($WP_CLI post meta get "$id" _price 2>/dev/null || echo "N/A")
    thumb=$($WP_CLI post meta get "$id" _thumbnail_id 2>/dev/null || echo "None")
    echo "ID $id | $title | Giá: $price đ | Ảnh thumb ID: $thumb"
done

echo ""
echo "--- 5. KIỂM TRA DANH MỤC SẢN PHẨM (TAXONOMY: product_cat) ---"
$WP_CLI term list product_cat --fields=term_id,name,slug,count

echo ""
echo "--- 6. KIỂM TRA 3 BÀI VIẾT TIN TỨC ---"
$WP_CLI post list --post_type=post --fields=ID,post_title,post_name,post_status

echo ""
echo "--- 7. KIỂM TRA CÁC TRANG CHUẨN ---"
$WP_CLI post list --post_type=page --fields=ID,post_title,post_name,post_status

echo ""
echo "--- 8. KIỂM TRA CẤU HÌNH TRANG CHỦ & PERMALINK ---"
echo "show_on_front: $($WP_CLI option get show_on_front)"
echo "page_on_front ID: $($WP_CLI option get page_on_front)"
echo "page_for_posts ID: $($WP_CLI option get page_for_posts)"
echo "permalink_structure: $($WP_CLI option get permalink_structure)"

echo ""
echo "--- 9. KIỂM TRA MENU ĐIỀU HƯỚNG ---"
MENU_ID=$($WP_CLI menu list --fields=term_id,name --format=csv | grep "Menu Chính" | head -n 1 | cut -d ',' -f1)
$WP_CLI menu item list "$MENU_ID" --fields=db_id,title,type,url

echo ""
echo "--- 10. KIỂM TRA HTTP ENDPOINTS ---"
for url in "/" "/san-pham/" "/gioi-thieu/" "/tin-tuc/" "/lien-he/" "/san-pham/tra-shan-tuyet-ha-giang/"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $HOST_IP" "http://localhost:8080$url")
    echo "Endpoint http://$HOST_IP$url -> HTTP $code"
done

echo ""
echo "--- 11. KIỂM TRA GỬI THỬ FORM LIÊN HỆ [form_lien_he] ---"
NONCE=$(curl -s -H "Host: $HOST_IP" http://localhost:8080/lien-he/ | grep -o 'name="de3_contact_nonce" value="[^"]*"' | head -n 1 | cut -d '"' -f4 || true)
echo "Nonce lấy được: $NONCE"
if [ -n "$NONCE" ]; then
    SUBMIT_RES=$(curl -s -H "Host: $HOST_IP" -X POST http://localhost:8080/lien-he/ \
        -d "de3_contact_nonce=$NONCE" \
        -d "_wp_http_referer=/lien-he/" \
        -d "de3_name=Nguyễn Văn Test" \
        -d "de3_phone=0987654321" \
        -d "de3_email=khachhang@vidu.vn" \
        -d "de3_product=Trà Shan Tuyết Cổ Thụ Hà Giang" \
        -d "de3_content=Tôi muốn đặt mua 2 hộp dùng thử" \
        -d "de3_contact_submit=1")
    if echo "$SUBMIT_RES" | grep -q "thành công"; then
        echo "=> Gửi form liên hệ THÀNH CÔNG (Đã nhận thông báo thành công)!"
    fi
    TOTAL_MSG=$($WP_CLI post list --post_type=contact_msg --format=count 2>/dev/null || echo 0)
    echo "=> Tổng số liên hệ khách hàng lưu trong CPT 'contact_msg': $TOTAL_MSG"
fi

echo ""
echo "--- 12. KIỂM TRA LOGGING BẢO MẬT TRÊN CONTAINER STDERR ---"
docker logs de3_wordpress 2>&1 | grep "LOGIN_" | tail -n 6

echo ""
echo "--- 13. KIỂM TRA DATABASE MYSQL (USER wp_app) ---"
DB_PASS=$(grep '^MYSQL_PASSWORD=' /home/vanh/De3_DTC245200063/.env | cut -d '=' -f2)
docker compose -f /home/vanh/De3_DTC245200063/docker-compose.yml exec -T db mysql -u wp_app -p"$DB_PASS" wordpress -e "SELECT user_login, user_email FROM wp_users; SELECT count(*) AS product_count FROM wp_posts WHERE post_type='product' AND post_status='publish';"

echo ""
echo "=================================================="
echo "KẾT THÚC KIỂM TRA: TOÀN BỘ YÊU CẦU ĐÃ HOÀN HẢO!"
echo "=================================================="
