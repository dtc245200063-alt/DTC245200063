-- Initialization script for MySQL database
CREATE DATABASE IF NOT EXISTS `wordpress` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wp_app'@'%';

-- Prometheus mysqld_exporter user
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'WP_Export_2026_rT5vN1' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'%';
GRANT SELECT ON performance_schema.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
