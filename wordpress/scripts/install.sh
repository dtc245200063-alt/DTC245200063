#!/bin/bash
set -e

echo "=== STARTING WORDPRESS AUTOMATIC INSTALLATION (IDEMPOTENT) ==="

WP_CLI="wp --allow-root"

# Source environment if available
if [ -f /var/www/html/wp-config.php ]; then
    echo "wp-config.php already exists."
fi

# 1. Check if WordPress core is installed
if ! $WP_CLI core is-installed 2>/dev/null; then
    echo "--- Installing WordPress Core ---"
    $WP_CLI core install \
        --url="http://192.168.102.128:8080" \
        --title="Trà & Cà Phê Đặc Sản Việt Nam" \
        --admin_user="${WP_ADMIN_USER:-quantri}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL:-quantri@ictu.edu.vn}" \
        --skip-email
else
    echo "--- WordPress Core is already installed ---"
fi

# 2. General site settings
echo "--- Configuring General Settings ---"
$WP_CLI option update blogdescription "Tinh hoa trà & cà phê di sản đất Việt"
$WP_CLI option update timezone_string "Asia/Ho_Chi_Minh"
$WP_CLI rewrite structure '/%postname%/'

# Try installing Vietnamese language pack
echo "--- Setting Language ---"
$WP_CLI language core install vi --activate 2>/dev/null || true
$WP_CLI site switch-language vi 2>/dev/null || true

# 3. Create or update Editor User
echo "--- Ensuring Editor User exists ---"
if ! $WP_CLI user get "${WP_EDITOR_USER:-bientap01}" --field=ID 2>/dev/null; then
    $WP_CLI user create "${WP_EDITOR_USER:-bientap01}" "${WP_EDITOR_EMAIL:-bientap01@ictu.edu.vn}" \
        --role=editor \
        --user_pass="${WP_EDITOR_PASSWORD}" \
        --display_name="Biên Tập Viên 01"
    echo "Created editor user ${WP_EDITOR_USER:-bientap01}"
else
    $WP_CLI user update "${WP_EDITOR_USER:-bientap01}" \
        --user_pass="${WP_EDITOR_PASSWORD}" \
        --role=editor 2>/dev/null || true
    echo "Editor user ${WP_EDITOR_USER:-bientap01} verified."
fi

# 4. Create Product Categories (Taxonomy: product_cat)
echo "--- Setting up Product Categories ---"
$WP_CLI term create product_cat "Trà đặc sản" --slug=tra-dac-san --description="Các dòng trà cổ thụ, trà ướp hương truyền thống vùng cao Việt Nam" 2>/dev/null || true
$WP_CLI term create product_cat "Cà phê đặc sản" --slug=ca-phe-dac-san --description="Hạt cà phê Robusta và Arabica tuyển chọn từ thủ phủ Tây Nguyên và Đà Lạt" 2>/dev/null || true

# 5. Generate seed images
echo "--- Generating Product Seed Images ---"
php /scripts/generate_images.php

# 6. Seed 12 Products
echo "--- Seeding 12 Products ---"
SEED_DIR="/var/www/html/wp-content/uploads/seed_images"

create_product() {
    local title="$1"
    local slug="$2"
    local price="$3"
    local cat_slug="$4"
    local img_name="$5"
    local excerpt="$6"
    local content="$7"

    local existing_id=$($WP_CLI post list --post_type=product --name="$slug" --field=ID)
    if [ -n "$existing_id" ]; then
        echo "Product '$slug' already exists (ID: $existing_id). Skipping creation."
        # ensure price meta
        $WP_CLI post meta update "$existing_id" _price "$price"
        return
    fi

    local post_id=$($WP_CLI post create \
        --post_type=product \
        --post_title="$title" \
        --post_name="$slug" \
        --post_status=publish \
        --post_excerpt="$excerpt" \
        --post_content="$content" \
        --porcelain)

    $WP_CLI post meta update "$post_id" _price "$price"
    $WP_CLI post term set "$post_id" product_cat "$cat_slug"

    # Attach image if exists
    if [ -f "$SEED_DIR/$img_name" ]; then
        $WP_CLI media import "$SEED_DIR/$img_name" --post_id="$post_id" --featured_image --title="$title" 2>/dev/null || true
    fi

    echo "Created product: $title (ID: $post_id, Price: $price)"
}

# 6 Trà Products
create_product "Trà Shan Tuyết Cổ Thụ Hà Giang" "tra-shan-tuyet-ha-giang" "450000" "tra-dac-san" "tra-shan-tuyet.png" \
    "Búp trà non phủ lớp lông tơ trắng muốt thu hái từ những cây trà cổ thụ trên 300 năm tuổi tại đỉnh Tây Côn Lĩnh." \
    "Trà Shan Tuyết cổ thụ Hà Giang sinh trưởng tự nhiên ở độ cao hơn 2.000m so với mực nước biển, quanh năm chìm trong sương mù. Nước trà vàng óng ánh như mật ong, hương thơm ngát tựa hoa rừng, vị chát êm dịu ban đầu và hậu vị ngọt sâu lắng kéo dài."

create_product "Trà Tân Cương Đinh Ngọc Thái Nguyên" "tra-tan-cuong-dinh-ngoc" "650000" "tra-dac-san" "tra-tan-cuong.png" \
    "Dòng trà quý tộc bậc nhất đất Thái Nguyên, chỉ hái nguyên 1 đọt non vào buổi sớm mai khi sương chưa tan." \
    "Trà Đinh Ngọc Tân Cương được tuyển chọn từ những đồi trà ngon nhất vùng Tân Cương, sao thủ công bởi các nghệ nhân lão luyện. Cánh trà xoăn nhỏ đều tăm tắp, nước trà xanh sánh, thơm ngậy mùi cốm non thanh khiết đặc trưng."

create_product "Trà Oolong Tứ Quý Mộc Châu" "tra-oolong-tu-quy-moc-chau" "280000" "tra-dac-san" "tra-oolong.png" \
    "Búp trà Oolong lên men bán phần tự nhiên giữa cao nguyên Mộc Châu lộng gió." \
    "Trà Oolong Tứ Quý được chế biến theo công nghệ hiện đại kết hợp bí quyết ủ men truyền thống. Viên trà tròn đều bóng bẩy, nước trà vàng sáng trong trẻo, lưu hương hoa quả ngọt ngào và vị thanh mát sảng khoái."

create_product "Trà Sen Tây Hồ Thượng Hạng" "tra-sen-tay-ho-thuong-hang" "850000" "tra-dac-san" "tra-sen.png" \
    "Tuyệt phẩm trà ướp gạo sen Bách Diệp Hồ Tây - tinh hoa ngàn năm của văn hóa ẩm thực Hà Nội." \
    "Để làm ra 1kg Trà Sen Thượng Hạng cần tới 1.500 bông sen Bách Diệp tươi hái lúc bình minh. Hương thơm ngát tao nhã hòa quyện cùng vị chát thanh thoát của trà nõn tạo nên tách trà chuẩn mực phong vị quý phái."

create_product "Trà Lài Tự Nhiên Bảo Lộc" "tra-lai-tu-nhien-bao-loc" "190000" "tra-dac-san" "tra-lai.png" \
    "Hương hoa lài tinh khiết ướp cùng búp trà xanh tươi ngon xứ B'Lao sương phủ." \
    "Trà Lài Bảo Lộc mang hương thơm ngọt ngào tự nhiên không hương liệu hóa học. Tách trà thơm dịu nhẹ, giúp thư thái tinh thần, giải nhiệt và tốt cho sức khỏe tim mạch."

create_product "Trà Cung Đình Cố Đô Huế" "tra-cung-dinh-co-do-hue" "160000" "tra-dac-san" "tra-cung-dinh.png" \
    "Công thức trà thảo mộc hoàng gia tổng hợp từ 16 vị thảo mộc quý ngự dụng triều Nguyễn." \
    "Thành phần gồm atisô, cúc hoa, cỏ ngọt, hoài sơn, đảng sâm, tim sen, cam thảo... Trà có vị ngọt thanh tự nhiên của thảo mộc, bồi bổ khí huyết, hỗ trợ ngủ sâu và thanh lọc cơ thể."

# 6 Cà Phê Products
create_product "Cà Phê Robusta Mộc Buôn Ma Thuột" "ca-phe-robusta-buon-ma-thuot" "180000" "ca-phe-dac-san" "ca-phe-robusta.png" \
    "Hạt Robusta đất đỏ bazan chín mọng 100%, rang mộc độ vừa (Medium-Dark) đậm chất truyền thống." \
    "Cà phê Robusta Buôn Ma Thuột nổi tiếng với thể chất dày (heavy body), hương vị socola đắng ngọt, crema sánh vàng và hàm lượng cafein dồi dào đem lại sự tỉnh táo bứt phá."

create_product "Cà Phê Arabica Cầu Đất Đà Lạt" "ca-phe-arabica-cau-dat-da-lat" "240000" "ca-phe-dac-san" "ca-phe-arabica.png" \
    "Hạt Arabica trồng tại độ cao 1.650m - thiên đường Arabica ngon nhất Đông Nam Á." \
    "Được sơ chế ướt (Washed process) chuẩn specialty coffee. Hương thơm thanh nhã của hoa quả nhiệt đới, cam chanh tươi mát, vị chua thanh dịu dàng và hậu vị ngọt sâu."

create_product "Cà Phê Culi Đắk Lắk Đậm Đà" "ca-phe-culi-dak-lak" "210000" "ca-phe-dac-san" "ca-phe-culi.png" \
    "Những hạt cà phê tròn trịa độc nhất vô nhị chỉ chiếm khoảng 5% sản lượng mỗi mùa vụ." \
    "Hạt Culi tích tụ hàm lượng khoáng chất và cafein cao hơn hẳn hạt dẹp. Vị đắng gắt mạnh mẽ, hương thơm nồng nàn, thích hợp cho những người sành gu cà phê đậm chất Việt."

create_product "Cà Phê Chồn Huyền Thoại Tây Nguyên" "ca-phe-chon-huyen-thoai-tay-nguyen" "1200000" "ca-phe-dac-san" "ca-phe-chon.png" \
    "Thức uống xa xỉ với quá trình ủ men enzyme sinh học tự nhiên kỳ diệu." \
    "Dòng cà phê chồn trang trại tự nhiên với vị bùi béo ngậy, phảng phất hương khói, socola đen và siro phong. Vị đắng mượt như nhung làm say đắm mọi tín đồ ẩm thực sành điệu."

create_product "Cà Phê Moka Sơn La Thơm Nồng" "ca-phe-moka-son-la" "260000" "ca-phe-dac-san" "ca-phe-moka.png" \
    "Giống Moka cổ quý hiếm gieo trồng trên các triền đồi Tây Bắc đầy nắng và gió." \
    "Hạt Moka Sơn La có hương vị phức hợp độc đáo: thoảng hương hoa nhài, thảo quả núi rừng hòa cùng vị chua thanh tao nhã của táo xanh."

create_product "Cà Phê Phin Rang Mộc Di Linh" "ca-phe-phin-rang-moc-di-linh" "175000" "ca-phe-dac-san" "ca-phe-phin.png" \
    "Phối trộn hoàn hảo theo tỷ lệ vàng 70% Robusta & 30% Arabica chuyên dùng cho pha phin truyền thống." \
    "Giọt cà phê nhỏ chậm rãi qua phin nhôm, mang lại tách cà phê sữa đá béo ngậy thơm nức mũi hoặc ly cà phê đen đá sánh đậm, không pha tẩm bất kỳ phụ gia nào."

# 7. Seed 3 News / Blog Posts
echo "--- Seeding 3 Blog Posts ---"
create_post() {
    local title="$1"
    local slug="$2"
    local excerpt="$3"
    local content="$4"

    local existing_id=$($WP_CLI post list --post_type=post --name="$slug" --field=ID)
    if [ -n "$existing_id" ]; then
        echo "Post '$slug' already exists. Skipping."
        return
    fi

    $WP_CLI post create \
        --post_title="$title" \
        --post_name="$slug" \
        --post_status=publish \
        --post_excerpt="$excerpt" \
        --post_content="$content"
    echo "Created blog post: $title"
}

create_post "Khám phá vùng trà Shan Tuyết cổ thụ trên đỉnh Tây Côn Lĩnh" \
    "kham-pha-vung-tra-shan-tuyet-ha-giang" \
    "Hành trình vượt mây lên đỉnh Tây Côn Lĩnh chiêm ngưỡng những cụ cây trà cổ thụ ngàn năm tuổi." \
    "<p>Nằm ở độ cao hơn 2.400 mét so với mực nước biển, Tây Côn Lĩnh (Hà Giang) được ví như nóc nhà vùng Đông Bắc. Nơi đây là cái nôi của những rừng trà Shan Tuyết cổ thụ hàng trăm năm tuổi, rêu phong bám đầy thân cây xù xì.</p><p>Người đồng bào Dao, Mông bản địa thu hái từng búp trà trong làn sương sớm tinh khôi, chế biến thủ công giữ trọn vẹn tinh túy đất trời. Nhấp một ngụm trà Shan Tuyết, ta như cảm nhận được cả sự hùng vĩ, thanh sạch của đại ngàn non cao.</p>"

create_post "Bí quyết pha cà phê phin đậm đà chuẩn vị truyền thống Việt Nam" \
    "bi-quyet-pha-ca-phe-phin-dam-da" \
    "Những lưu ý vàng về nhiệt độ nước, độ mịn hạt và thời gian ủ để có ly cà phê phin hoàn hảo." \
    "<p>Cà phê phin không đơn thuần là một thức uống, đó là nét văn hóa thưởng thức chậm rãi của người Việt. Để có được một ly cà phê phin trọn vị:</p><ul><li><strong>Bột cà phê:</strong> Nên xay độ thô vừa phải, nguyên chất rang mộc không tẩm bơ đường.</li><li><strong>Tỷ lệ vàng:</strong> 25g bột cà phê cho khoảng 80-100ml nước nóng 92-95°C.</li><li><strong>Kỹ thuật ủ:</strong> Rót trước 30ml nước vào phin và nắp đáy, ủ trong 2-3 phút để bột cà phê nở đều trước khi châm nước lần hai.</li></ul><p>Từng giọt cà phê nhỏ tí tách chậm rãi đem lại hương thơm ngào ngạt và vị đậm đà khó quên.</p>"

create_post "Hành trình đưa hạt cà phê Arabica Cầu Đất vươn tầm thế giới" \
    "hanh-trinh-ca-phe-arabica-cau-dat" \
    "Vùng đất Cầu Đất Đà Lạt với khí hậu ôn đới lý tưởng đang khẳng định vị thế cà phê đặc sản Việt." \
    "<p>Từ đầu thế kỷ 20, người Pháp đã nhận ra tiềm năng phi thường của vùng Cầu Đất (Đà Lạt) để trồng giống cà phê Bourbon và Typica danh tiếng. Với độ cao trên 1.600m, đất đỏ bazan trù phú cùng khí hậu mát mẻ quanh năm, hạt Arabica Cầu Đất sở hữu độ chua thanh trang nhã và hương thơm tựa hoa cỏ mùa xuân.</p><p>Ngày nay, bằng quy trình canh tác hữu cơ và sơ chế chuyên nghiệp, Arabica Cầu Đất đã có mặt tại nhiều chuỗi cà phê danh tiếng toàn cầu.</p>"

# 8. Create Static Pages
echo "--- Setting up Standard Pages ---"
create_page() {
    local title="$1"
    local slug="$2"
    local content="$3"

    local page_id=$($WP_CLI post list --post_type=page --name="$slug" --field=ID)
    if [ -z "$page_id" ]; then
        page_id=$($WP_CLI post create \
            --post_type=page \
            --post_title="$title" \
            --post_name="$slug" \
            --post_status=publish \
            --post_content="$content" \
            --porcelain)
        echo "Created page '$title' (ID: $page_id)" >&2
    else
        echo "Page '$title' exists (ID: $page_id)." >&2
    fi
    echo "$page_id"
}

HOME_ID=$(create_page "Trang chủ" "trang-chu" '
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="de3-home-hero" style="background: linear-gradient(135deg, #1b5e20 0%, #2e7d32 100%); color:#fff; padding:60px 20px; border-radius:16px; text-align:center; margin-bottom:40px;">
    <h1 style="font-size:38px; font-weight:800; margin-bottom:15px; color:#fff;">TINH HOA TRÀ & CÀ PHÊ ĐẶC SẢN VIỆT NAM</h1>
    <p style="font-size:18px; max-width:750px; margin:0 auto 25px auto; color:#e8f5e9;">Khám phá các sản vật trứ danh từ những vùng đất danh tiếng: Trà cổ thụ Tây Côn Lĩnh, Tân Cương Thái Nguyên đến Robusta Buôn Ma Thuột và Arabica Cầu Đất.</p>
    <a href="/san-pham/" style="display:inline-block; background:#c67c3b; color:#fff; padding:14px 32px; font-weight:700; border-radius:30px; text-decoration:none; box-shadow:0 4px 15px rgba(0,0,0,0.2);">Xem tất cả sản phẩm</a>
</div>
<!-- /wp:group -->

<h2 style="text-align:center; font-size:28px; font-weight:800; margin-bottom:10px; color:#1b5e20;">SẢN PHẨM NỔI BẬT</h2>
<p style="text-align:center; color:#666; margin-bottom:30px;">Tuyển chọn những phẩm trà và hạt cà phê thượng hạng nhất</p>

[danh_sach_san_pham limit="6"]

<div style="text-align:center; margin-top:30px;">
    <a href="/san-pham/" style="display:inline-block; padding:12px 28px; background:#1b5e20; color:#fff; border-radius:6px; font-weight:600; text-decoration:none;">Xem thêm nhiều sản phẩm khác →</a>
</div>
')

ABOUT_ID=$(create_page "Giới thiệu" "gioi-thieu" '
<h2>Về Thương Hiệu Trà & Cà Phê Đặc Sản Việt Nam</h2>
<p>Chúng tôi tự hào là cầu nối đưa những giá trị nguyên bản của nông sản Việt Nam vươn xa. Mỗi búp trà Shan Tuyết hay hạt cà phê Robusta, Arabica đều là kết tinh của đất trời Tây Bắc và đại ngàn Tây Nguyên.</p>
<h3>Cam Kết Chất Lượng:</h3>
<ul>
    <li><strong>100% Nguyên Chất:</strong> Không tẩm ướp hương liệu nhân tạo, không hóa chất bảo quản.</li>
    <li><strong>Nguồn Gốc Minh Bạch:</strong> Thu hoạch trực tiếp từ các hợp tác xã và hộ nông dân uy tín.</li>
    <li><strong>Chế Biến Chuẩn Mực:</strong> Áp dụng bí quyết sao trà cổ truyền kết hợp kỹ thuật sơ chế specialty coffee hiện đại.</li>
</ul>
')

PRODUCTS_ID=$(create_page "Sản phẩm" "san-pham" '
<h1 style="text-align:center; color:#1b5e20; font-weight:800; margin-bottom:10px;">DANH MỤC TRÀ & CÀ PHÊ ĐẶC SẢN</h1>
<p style="text-align:center; color:#666; margin-bottom:30px;">Quý khách có thể lựa chọn theo danh mục hoặc nhấp xem chi tiết từng dòng sản phẩm</p>
[danh_sach_san_pham limit="12"]
')

NEWS_ID=$(create_page "Tin tức" "tin-tuc" 'Trang tin tức và văn hóa thưởng trà, cà phê.')

CONTACT_ID=$(create_page "Liên hệ" "lien-he" '
<h1 style="text-align:center; color:#1b5e20; font-weight:800; margin-bottom:10px;">LIÊN HỆ ĐẶT HÀNG & TƯ VẤN</h1>
<p style="text-align:center; color:#666; margin-bottom:25px;">Hãy để lại thông tin, chuyên viên của chúng tôi sẽ gọi lại tư vấn và gửi báo giá ưu đãi nhất cho bạn.</p>
[form_lien_he]
')

# Configure Static Front Page
$WP_CLI option update show_on_front page
$WP_CLI option update page_on_front "$HOME_ID"
$WP_CLI option update page_for_posts "$NEWS_ID"

# 9. Configure Main Navigation Menu
echo "--- Setting up Navigation Menu ---"
MENU_ID=$($WP_CLI menu list --fields=term_id,name --format=csv 2>/dev/null | grep "Menu Chính" | head -n 1 | cut -d ',' -f1 || true)

if [ -z "$MENU_ID" ]; then
    MENU_ID=$($WP_CLI menu create "Menu Chính" --porcelain 2>/dev/null || true)
fi

if [ -n "$MENU_ID" ]; then
    ITEM_COUNT=$($WP_CLI menu item list "$MENU_ID" --format=count 2>/dev/null || echo 0)
    if [ "$ITEM_COUNT" -eq 0 ]; then
        $WP_CLI menu item add-post "$MENU_ID" "$HOME_ID" --title="Trang chủ" 2>/dev/null || true
        $WP_CLI menu item add-post "$MENU_ID" "$ABOUT_ID" --title="Giới thiệu" 2>/dev/null || true
        $WP_CLI menu item add-post "$MENU_ID" "$PRODUCTS_ID" --title="Sản phẩm" 2>/dev/null || true
        $WP_CLI menu item add-post "$MENU_ID" "$NEWS_ID" --title="Tin tức" 2>/dev/null || true
        $WP_CLI menu item add-post "$MENU_ID" "$CONTACT_ID" --title="Liên hệ" 2>/dev/null || true
        $WP_CLI menu location assign "$MENU_ID" primary 2>/dev/null || true
        echo "Populated Menu Chính items (ID: $MENU_ID)."
    else
        echo "Menu Chính already exists with $ITEM_COUNT items."
    fi
fi

# 10. Flush rewrite rules
$WP_CLI rewrite flush

echo "=== WORDPRESS INSTALLATION & SEEDING COMPLETED SUCCESSFULLY ==="
