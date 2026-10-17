-- Initialization script for MySQL database
CREATE DATABASE IF NOT EXISTS `wordpress` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wp_app'@'%';
FLUSH PRIVILEGES;
