<?php
/**
 * Plugin Name: De3 Security Logging
 * Description: Logs authentication events (LOGIN_SUCCESS, LOGIN_FAILED) to STDERR for Loki & Promtail monitoring.
 * Author: Luong Viet Anh - DTC245200063
 * Version: 1.0.0
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Retrieve real client IP address from proxy headers or remote addr.
 */
function de3_get_client_ip() {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $parts = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        $ip = trim($parts[0]);
        if (filter_var($ip, FILTER_VALIDATE_IP)) {
            return $ip;
        }
    }
    if (!empty($_SERVER['HTTP_X_REAL_IP'])) {
        $ip = trim($_SERVER['HTTP_X_REAL_IP']);
        if (filter_var($ip, FILTER_VALIDATE_IP)) {
            return $ip;
        }
    }
    return $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
}

/**
 * Hook into wp_login_failed
 */
add_action('wp_login_failed', function($username) {
    $ip = de3_get_client_ip();
    $clean_user = sanitize_user($username);
    if (empty($clean_user)) {
        $clean_user = 'empty_user';
    }
    $reason = username_exists($clean_user) ? 'wrong_password' : 'unknown_user';
    
    $message = sprintf("LOGIN_FAILED ip=%s user=%s reason=%s\n", $ip, $clean_user, $reason);
    @file_put_contents('php://stderr', $message);
}, 10, 1);

/**
 * Hook into wp_login
 */
add_action('wp_login', function($user_login, $user) {
    $ip = de3_get_client_ip();
    $username = is_object($user) ? $user->user_login : $user_login;
    $clean_user = sanitize_user($username);
    
    $message = sprintf("LOGIN_SUCCESS ip=%s user=%s\n", $ip, $clean_user);
    @file_put_contents('php://stderr', $message);
}, 10, 2);
