<?php
/**
 * Plugin Name: De3 Product Catalog & Contact Form
 * Description: Custom Post Type "Sản phẩm", Taxonomy "Danh mục sản phẩm", Shortcodes [danh_sach_san_pham], [form_lien_he] and UI styling.
 * Author: Luong Viet Anh - DTC245200063
 * Version: 1.0.0
 */

if (!defined('ABSPATH')) {
    exit;
}

// 1. Register Custom Post Type: product (Sản phẩm)
add_action('init', function() {
    $labels = [
        'name'               => 'Sản phẩm',
        'singular_name'      => 'Sản phẩm',
        'menu_name'          => 'Sản phẩm',
        'add_new'            => 'Thêm sản phẩm',
        'add_new_item'       => 'Thêm sản phẩm mới',
        'edit_item'          => 'Sửa sản phẩm',
        'new_item'           => 'Sản phẩm mới',
        'view_item'          => 'Xem sản phẩm',
        'search_items'       => 'Tìm kiếm sản phẩm',
        'not_found'          => 'Không tìm thấy sản phẩm nào',
        'not_found_in_trash' => 'Không có sản phẩm trong thùng rác',
    ];

    $args = [
        'labels'             => $labels,
        'public'             => true,
        'publicly_queryable' => true,
        'show_ui'            => true,
        'show_in_menu'       => true,
        'query_var'          => true,
        'rewrite'            => ['slug' => 'san-pham', 'with_front' => false],
        'capability_type'    => 'post',
        'has_archive'        => false,
        'hierarchical'       => false,
        'menu_position'      => 5,
        'menu_icon'          => 'dashicons-coffee',
        'supports'           => ['title', 'editor', 'thumbnail', 'excerpt', 'custom-fields'],
        'show_in_rest'       => true,
    ];

    register_post_type('product', $args);

    // Register Taxonomy: product_cat (Danh mục sản phẩm)
    $tax_labels = [
        'name'              => 'Danh mục sản phẩm',
        'singular_name'     => 'Danh mục sản phẩm',
        'search_items'      => 'Tìm danh mục',
        'all_items'         => 'Tất cả danh mục',
        'parent_item'       => 'Danh mục cha',
        'parent_item_colon' => 'Danh mục cha:',
        'edit_item'         => 'Sửa danh mục',
        'update_item'       => 'Cập nhật danh mục',
        'add_new_item'      => 'Thêm danh mục mới',
        'new_item_name'     => 'Tên danh mục mới',
        'menu_name'         => 'Danh mục sản phẩm',
    ];

    register_taxonomy('product_cat', ['product'], [
        'hierarchical'      => true,
        'labels'            => $tax_labels,
        'show_ui'           => true,
        'show_admin_column' => true,
        'query_var'         => true,
        'rewrite'           => ['slug' => 'danh-muc-san-pham'],
        'show_in_rest'      => true,
    ]);

    // Register Contact Message CPT (Lưu thông tin liên hệ)
    register_post_type('contact_msg', [
        'labels' => [
            'name'          => 'Liên hệ khách hàng',
            'singular_name' => 'Tin nhắn liên hệ',
        ],
        'public'       => false,
        'show_ui'      => true,
        'show_in_menu' => true,
        'menu_icon'    => 'dashicons-email',
        'supports'     => ['title', 'editor', 'custom-fields'],
    ]);
});

// 2. Shortcode [danh_sach_san_pham category="..."]
add_shortcode('danh_sach_san_pham', function($atts) {
    $atts = shortcode_atts([
        'category' => '',
        'limit'    => 12,
    ], $atts, 'danh_sach_san_pham');

    $selected_cat = isset($_GET['cat']) ? sanitize_text_field($_GET['cat']) : $atts['category'];

    $tax_query = [];
    if (!empty($selected_cat)) {
        $tax_query[] = [
            'taxonomy' => 'product_cat',
            'field'    => 'slug',
            'terms'    => $selected_cat,
        ];
    }

    $query = new WP_Query([
        'post_type'      => 'product',
        'posts_per_page' => intval($atts['limit']),
        'tax_query'      => $tax_query,
        'orderby'        => 'date',
        'order'          => 'DESC',
    ]);

    $categories = get_terms([
        'taxonomy'   => 'product_cat',
        'hide_empty' => false,
    ]);

    ob_start();
    ?>
    <div class="de3-catalog-container">
        <!-- Bộ lọc danh mục -->
        <div class="de3-filter-bar">
            <a href="?cat=" class="de3-filter-btn <?php echo empty($selected_cat) ? 'active' : ''; ?>">Tất cả sản phẩm</a>
            <?php if (!empty($categories) && !is_wp_error($categories)): ?>
                <?php foreach ($categories as $cat): ?>
                    <a href="?cat=<?php echo esc_attr($cat->slug); ?>" class="de3-filter-btn <?php echo ($selected_cat === $cat->slug) ? 'active' : ''; ?>">
                        <?php echo esc_html($cat->name); ?> (<?php echo intval($cat->count); ?>)
                    </a>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>

        <!-- Lưới sản phẩm -->
        <?php if ($query->have_posts()): ?>
            <div class="de3-product-grid">
                <?php while ($query->have_posts()): $query->the_post();
                    $price = get_post_meta(get_the_ID(), '_price', true);
                    $formatted_price = !empty($price) ? number_format(floatval($price), 0, ',', '.') . ' ₫' : 'Liên hệ';
                    $product_terms = get_the_terms(get_the_ID(), 'product_cat');
                    $cat_name = ($product_terms && !is_wp_error($product_terms)) ? $product_terms[0]->name : 'Đặc sản';
                    $thumb_url = get_the_post_thumbnail_url(get_the_ID(), 'medium');
                    if (empty($thumb_url)) {
                        $thumb_url = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300"><rect fill="%232e7d32" width="400" height="300"/><text fill="%23ffffff" font-family="sans-serif" font-size="22" font-weight="bold" x="50%" y="50%" text-anchor="middle" dominant-baseline="middle">Đặc Sản Việt Nam</text></svg>';
                    }
                ?>
                    <div class="de3-product-card">
                        <div class="de3-product-thumb">
                            <span class="de3-cat-badge"><?php echo esc_html($cat_name); ?></span>
                            <a href="<?php the_permalink(); ?>">
                                <img src="<?php echo esc_url($thumb_url); ?>" alt="<?php the_title_attribute(); ?>" loading="lazy" />
                            </a>
                        </div>
                        <div class="de3-product-info">
                            <h3 class="de3-product-title">
                                <a href="<?php the_permalink(); ?>"><?php the_title(); ?></a>
                            </h3>
                            <div class="de3-product-price"><?php echo esc_html($formatted_price); ?></div>
                            <div class="de3-product-desc"><?php echo wp_trim_words(get_the_excerpt(), 18, '...'); ?></div>
                            <div class="de3-product-actions">
                                <a href="<?php the_permalink(); ?>" class="de3-btn-view">Chi tiết</a>
                                <a href="/lien-he/?sp=<?php echo urlencode(get_the_title()); ?>" class="de3-btn-buy">Đặt mua</a>
                            </div>
                        </div>
                    </div>
                <?php endwhile; wp_reset_postdata(); ?>
            </div>
        <?php else: ?>
            <p class="de3-no-products">Hiện chưa có sản phẩm nào trong danh mục này.</p>
        <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
});

// 3. Template chi tiết sản phẩm đơn lẻ (Single Product View)
add_filter('the_content', function($content) {
    if (is_singular('product') && in_the_loop() && is_main_query()) {
        $price = get_post_meta(get_the_ID(), '_price', true);
        $formatted_price = !empty($price) ? number_format(floatval($price), 0, ',', '.') . ' ₫' : 'Liên hệ';
        $terms = get_the_terms(get_the_ID(), 'product_cat');
        $cat_name = ($terms && !is_wp_error($terms)) ? $terms[0]->name : 'Đặc sản';

        $custom_box = '
        <div class="de3-single-product-box">
            <div class="de3-single-meta">
                <span class="de3-badge-large">' . esc_html($cat_name) . '</span>
                <div class="de3-single-price">' . esc_html($formatted_price) . '</div>
                <div class="de3-single-status">Tình trạng: <strong style="color:#2e7d32">Còn hàng (Chính hãng 100%)</strong></div>
            </div>
            <div class="de3-single-cta">
                <a href="/lien-he/?sp=' . urlencode(get_the_title()) . '" class="de3-btn-order">Đặt hàng / Tư vấn ngay</a>
                <a href="/san-pham/" class="de3-btn-back">← Quay lại danh sách sản phẩm</a>
            </div>
        </div>';

        return $custom_box . '<div class="de3-single-description"><h3>Mô tả sản phẩm</h3>' . $content . '</div>';
    }
    return $content;
});

// 4. Shortcode [form_lien_he]
add_shortcode('form_lien_he', function() {
    $msg = '';
    $default_sp = isset($_GET['sp']) ? sanitize_text_field($_GET['sp']) : '';

    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['de3_contact_submit'])) {
        if (!isset($_POST['de3_contact_nonce']) || !wp_verify_nonce($_POST['de3_contact_nonce'], 'de3_contact_action')) {
            $msg = '<div class="de3-alert de3-alert-error">Lỗi xác thực bảo mật! Vui lòng thử lại.</div>';
        } else {
            $name    = sanitize_text_field($_POST['de3_name'] ?? '');
            $phone   = sanitize_text_field($_POST['de3_phone'] ?? '');
            $email   = sanitize_email($_POST['de3_email'] ?? '');
            $product = sanitize_text_field($_POST['de3_product'] ?? '');
            $content = sanitize_textarea_field($_POST['de3_content'] ?? '');

            if (empty($name) || empty($phone)) {
                $msg = '<div class="de3-alert de3-alert-error">Vui lòng nhập họ tên và số điện thoại!</div>';
            } else {
                $post_title = $name . ' (' . $phone . ')';
                if (!empty($product)) {
                    $post_title .= ' - Quan tâm: ' . $product;
                }
                $post_body = "Họ tên: {$name}\nSố điện thoại: {$phone}\nEmail: {$email}\nSản phẩm quan tâm: {$product}\nNội dung: {$content}";

                wp_insert_post([
                    'post_type'    => 'contact_msg',
                    'post_title'   => $post_title,
                    'post_content' => $post_body,
                    'post_status'  => 'publish',
                ]);

                $msg = '<div class="de3-alert de3-alert-success">✓ Cảm ơn bạn <strong>' . esc_html($name) . '</strong>! Yêu cầu của bạn đã được gửi thành công. Chúng tôi sẽ liên hệ trong ít phút.</div>';
            }
        }
    }

    ob_start();
    ?>
    <div class="de3-contact-wrapper">
        <?php echo $msg; ?>
        <form method="POST" action="" class="de3-contact-form">
            <?php wp_nonce_field('de3_contact_action', 'de3_contact_nonce'); ?>
            <div class="de3-form-group">
                <label for="de3_name">Họ và tên <span class="req">*</span></label>
                <input type="text" id="de3_name" name="de3_name" required placeholder="Nguyễn Văn A" />
            </div>
            <div class="de3-form-row">
                <div class="de3-form-group">
                    <label for="de3_phone">Số điện thoại <span class="req">*</span></label>
                    <input type="tel" id="de3_phone" name="de3_phone" required placeholder="0912 345 678" />
                </div>
                <div class="de3-form-group">
                    <label for="de3_email">Email liên hệ</label>
                    <input type="email" id="de3_email" name="de3_email" placeholder="email@vidu.vn" />
                </div>
            </div>
            <div class="de3-form-group">
                <label for="de3_product">Sản phẩm cần tư vấn</label>
                <input type="text" id="de3_product" name="de3_product" value="<?php echo esc_attr($default_sp); ?>" placeholder="Tên sản phẩm quan tâm" />
            </div>
            <div class="de3-form-group">
                <label for="de3_content">Lời nhắn / Địa chỉ nhận hàng</label>
                <textarea id="de3_content" name="de3_content" rows="4" placeholder="Nhập địa chỉ giao hàng hoặc câu hỏi của bạn..."></textarea>
            </div>
            <button type="submit" name="de3_contact_submit" class="de3-btn-submit">Gửi thông tin liên hệ</button>
        </form>
    </div>
    <?php
    return ob_get_clean();
});

// 5. Enqueue Custom CSS for Luxury Tea & Coffee Theme
add_action('wp_head', function() {
    ?>
    <style id="de3-custom-styles">
        :root {
            --de3-primary: #1b5e20;
            --de3-primary-hover: #2e7d32;
            --de3-accent: #c67c3b;
            --de3-dark: #2c2523;
            --de3-bg: #f9f8f6;
            --de3-card-bg: #ffffff;
            --de3-radius: 12px;
            --de3-shadow: 0 4px 20px rgba(0,0,0,0.06);
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
            background-color: var(--de3-bg);
            color: var(--de3-dark);
        }
        /* Product Catalog Styling */
        .de3-catalog-container {
            max-width: 1200px;
            margin: 20px auto;
            padding: 0 15px;
        }
        .de3-filter-bar {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-bottom: 30px;
            justify-content: center;
        }
        .de3-filter-btn {
            display: inline-block;
            padding: 8px 18px;
            background: #fff;
            color: #444;
            border: 1px solid #ddd;
            border-radius: 25px;
            text-decoration: none;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.2s ease;
        }
        .de3-filter-btn:hover, .de3-filter-btn.active {
            background: var(--de3-primary);
            color: #fff;
            border-color: var(--de3-primary);
            box-shadow: 0 2px 8px rgba(27,94,32,0.3);
        }
        .de3-product-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
            gap: 25px;
        }
        .de3-product-card {
            background: var(--de3-card-bg);
            border-radius: var(--de3-radius);
            overflow: hidden;
            box-shadow: var(--de3-shadow);
            transition: transform 0.25s ease, box-shadow 0.25s ease;
            display: flex;
            flex-direction: column;
            border: 1px solid #edebe8;
        }
        .de3-product-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.12);
        }
        .de3-product-thumb {
            position: relative;
            width: 100%;
            height: 200px;
            background: #f0eee9;
            overflow: hidden;
        }
        .de3-product-thumb img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.3s ease;
        }
        .de3-product-card:hover .de3-product-thumb img {
            transform: scale(1.05);
        }
        .de3-cat-badge {
            position: absolute;
            top: 10px;
            left: 10px;
            background: rgba(27,94,32,0.85);
            color: #fff;
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 12px;
            text-transform: uppercase;
            z-index: 2;
        }
        .de3-product-info {
            padding: 18px;
            display: flex;
            flex-direction: column;
            flex-grow: 1;
        }
        .de3-product-title {
            font-size: 16px;
            font-weight: 700;
            margin: 0 0 8px 0;
            line-height: 1.4;
        }
        .de3-product-title a {
            color: var(--de3-dark);
            text-decoration: none;
        }
        .de3-product-title a:hover {
            color: var(--de3-primary);
        }
        .de3-product-price {
            font-size: 18px;
            font-weight: 800;
            color: var(--de3-accent);
            margin-bottom: 10px;
        }
        .de3-product-desc {
            font-size: 13px;
            color: #666;
            line-height: 1.5;
            margin-bottom: 16px;
            flex-grow: 1;
        }
        .de3-product-actions {
            display: flex;
            gap: 10px;
        }
        .de3-btn-view, .de3-btn-buy {
            flex: 1;
            text-align: center;
            padding: 8px 12px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            text-decoration: none;
            transition: all 0.2s ease;
        }
        .de3-btn-view {
            background: #eee;
            color: #333;
        }
        .de3-btn-view:hover {
            background: #ddd;
        }
        .de3-btn-buy {
            background: var(--de3-primary);
            color: #fff;
        }
        .de3-btn-buy:hover {
            background: var(--de3-primary-hover);
        }
        /* Single Product Box */
        .de3-single-product-box {
            background: #fff;
            padding: 24px;
            border-radius: 12px;
            border-left: 5px solid var(--de3-primary);
            box-shadow: 0 4px 15px rgba(0,0,0,0.05);
            margin-bottom: 30px;
        }
        .de3-single-price {
            font-size: 26px;
            font-weight: 800;
            color: var(--de3-accent);
            margin: 10px 0;
        }
        .de3-single-cta {
            display: flex;
            gap: 15px;
            margin-top: 15px;
            flex-wrap: wrap;
        }
        .de3-btn-order {
            background: var(--de3-primary);
            color: #fff;
            padding: 12px 24px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 700;
            display: inline-block;
        }
        .de3-btn-back {
            background: #f0f0f0;
            color: #444;
            padding: 12px 20px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            display: inline-block;
        }
        /* Contact Form */
        .de3-contact-wrapper {
            max-width: 650px;
            margin: 20px auto;
            background: #fff;
            padding: 30px;
            border-radius: 12px;
            box-shadow: var(--de3-shadow);
        }
        .de3-contact-form .de3-form-group {
            margin-bottom: 18px;
        }
        .de3-contact-form .de3-form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        .de3-contact-form label {
            display: block;
            margin-bottom: 6px;
            font-weight: 600;
            font-size: 14px;
        }
        .de3-contact-form label .req {
            color: red;
        }
        .de3-contact-form input, .de3-contact-form textarea {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid #ccc;
            border-radius: 6px;
            font-size: 14px;
            box-sizing: border-box;
        }
        .de3-contact-form input:focus, .de3-contact-form textarea:focus {
            outline: none;
            border-color: var(--de3-primary);
            box-shadow: 0 0 0 3px rgba(27,94,32,0.15);
        }
        .de3-btn-submit {
            background: var(--de3-primary);
            color: #fff;
            border: none;
            padding: 12px 25px;
            font-size: 15px;
            font-weight: 700;
            border-radius: 6px;
            cursor: pointer;
            width: 100%;
            transition: background 0.2s ease;
        }
        .de3-btn-submit:hover {
            background: var(--de3-primary-hover);
        }
        .de3-alert {
            padding: 12px 18px;
            border-radius: 6px;
            margin-bottom: 20px;
            font-size: 14px;
        }
        .de3-alert-success {
            background: #e8f5e9;
            color: #2e7d32;
            border: 1px solid #c8e6c9;
        }
        .de3-alert-error {
            background: #ffebee;
            color: #c62828;
            border: 1px solid #ffcdd2;
        }
    </style>
    <?php
});
