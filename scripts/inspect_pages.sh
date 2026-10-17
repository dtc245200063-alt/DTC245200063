#!/bin/bash
cd /home/vanh/De3_DTC245200063
echo "=== MENUS ==="
docker compose run --rm wpcli menu list
echo "=== MENU ITEMS ==="
for m in $(docker compose run --rm wpcli menu list --field=term_id); do
    echo "Menu ID: $m"
    docker compose run --rm wpcli menu item list "$m" --fields=db_id,title,type,object_id,url
done
echo "=== PAGES ==="
docker compose run --rm wpcli post list --post_type=page --fields=ID,post_title,post_name,post_status,guid
echo "=== CHECK HTTP GET ON ALL PAGES ==="
for path in "/" "/gioi-thieu/" "/san-pham/" "/tin-tuc/" "/lien-he/"; do
    echo "URL: https://192.168.102.128$path"
    curl -k -s "https://192.168.102.128$path" | grep -iE "<title>|danh-muc-tabs|form-lien-he|entry-content" | head -n 5
done
