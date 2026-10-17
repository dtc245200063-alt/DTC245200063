<?php
/**
 * Plugin Name: De3 Security Hardening
 * Description: Implements application-level hardening: hides WP version, disables author enumeration, disables XML-RPC.
 * Author: Luong Viet Anh - DTC245200063
 * Version: 1.0.0
 */

if (!defined('ABSPATH')) {
    exit;
}

// 1. Remove WordPress generator meta tag & RSS generator
remove_action('wp_head', 'wp_generator');
add_filter('the_generator', '__return_empty_string');

// 2. Remove version query parameters from static assets (CSS/JS)
function de3_remove_asset_version($src) {
    if ($src && strpos($src, 'ver=')) {
        return remove_query_arg('ver', $src);
    }
    return $src;
}
add_filter('style_loader_src', 'de3_remove_asset_version', 9999);
add_filter('script_loader_src', 'de3_remove_asset_version', 9999);

// 3. Block author enumeration via /?author=N
add_action('init', function() {
    if (!is_admin() && isset($_REQUEST['author']) && is_numeric($_REQUEST['author'])) {
        wp_die('Truy cập bị từ chối: Quét danh sách người dùng đã bị vô hiệu hóa.', 'Truy cập bị từ chối', array('response' => 403));
    }
});

// 4. Disable REST API users endpoint for unauthenticated visitors
add_filter('rest_endpoints', function($endpoints) {
    if (!is_user_logged_in()) {
        if (isset($endpoints['/wp/v2/users'])) {
            unset($endpoints['/wp/v2/users']);
        }
        if (isset($endpoints['/wp/v2/users/(?P<id>[\d]+)'])) {
            unset($endpoints['/wp/v2/users/(?P<id>[\d]+)']);
        }
    }
    return $endpoints;
});

// 5. Completely disable XML-RPC
add_filter('xmlrpc_enabled', '__return_false');
