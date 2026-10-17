#!/bin/bash
set -e

# Script sinh chứng chỉ SSL tự ký cho Nginx Reverse Proxy
# Mặc định sử dụng IP: 192.168.102.128, hoặc nhận tham số truyền vào: ./gen-cert.sh <IP>

TARGET_IP="${1:-192.168.102.128}"
CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/certs"

mkdir -p "$CERT_DIR"

KEY_FILE="$CERT_DIR/server.key"
CRT_FILE="$CERT_DIR/server.crt"

echo "=== TẠO CHỨNG CHỈ SSL TỰ KÝ CHO IP: $TARGET_IP ==="

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CRT_FILE" \
    -subj "/C=VN/ST=ThaiNguyen/L=ThaiNguyen/O=DTC245200063/OU=IT/CN=$TARGET_IP" \
    -addext "subjectAltName=IP:$TARGET_IP,IP:127.0.0.1,DNS:localhost"

chmod 600 "$KEY_FILE"
chmod 644 "$CRT_FILE"

echo "✓ Đã sinh thành công:"
echo "  - Private Key : $KEY_FILE (được bảo vệ, trong .gitignore)"
echo "  - Certificate : $CRT_FILE"
openssl x509 -in "$CRT_FILE" -noout -subject -dates -ext subjectAltName
