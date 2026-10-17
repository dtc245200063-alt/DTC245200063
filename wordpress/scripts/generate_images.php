<?php
/**
 * Script generate placeholder product images using PHP GD
 */

$img_dir = '/var/www/html/wp-content/uploads/seed_images';
if (!file_exists($img_dir)) {
    mkdir($img_dir, 0777, true);
}

$items = [
    // Trà (Green palette)
    ['file' => 'tra-shan-tuyet.png', 'title' => 'Tra Shan Tuyet', 'sub' => 'Ha Giang 450.000d', 'color' => [34, 112, 62]],
    ['file' => 'tra-tan-cuong.png', 'title' => 'Tra Tan Cuong', 'sub' => 'Thai Nguyen 650.000d', 'color' => [46, 125, 50]],
    ['file' => 'tra-oolong.png', 'title' => 'Tra Oolong', 'sub' => 'Moc Chau 280.000d', 'color' => [56, 142, 60]],
    ['file' => 'tra-sen.png', 'title' => 'Tra Sen Tay Ho', 'sub' => 'Thuong Hang 850.000d', 'color' => [76, 175, 80]],
    ['file' => 'tra-lai.png', 'title' => 'Tra Lai Tu Nhien', 'sub' => 'Bao Loc 190.000d', 'color' => [102, 187, 106]],
    ['file' => 'tra-cung-dinh.png', 'title' => 'Tra Cung Dinh', 'sub' => 'Hue 160.000d', 'color' => [129, 199, 132]],

    // Cà phê (Warm brown/amber palette)
    ['file' => 'ca-phe-robusta.png', 'title' => 'Ca Phe Robusta', 'sub' => 'Buon Ma Thuot 180.000d', 'color' => [93, 64, 55]],
    ['file' => 'ca-phe-arabica.png', 'title' => 'Ca Phe Arabica', 'sub' => 'Cau Dat 240.000d', 'color' => [109, 76, 65]],
    ['file' => 'ca-phe-culi.png', 'title' => 'Ca Phe Culi', 'sub' => 'Dak Lak 210.000d', 'color' => [121, 85, 72]],
    ['file' => 'ca-phe-chon.png', 'title' => 'Ca Phe Chon', 'sub' => 'Tay Nguyen 1.200.000d', 'color' => [78, 52, 46]],
    ['file' => 'ca-phe-moka.png', 'title' => 'Ca Phe Moka', 'sub' => 'Son La 260.000d', 'color' => [141, 110, 99]],
    ['file' => 'ca-phe-phin.png', 'title' => 'Ca Phe Phin', 'sub' => 'Di Linh 175.000d', 'color' => [62, 39, 35]],
];

foreach ($items as $item) {
    $path = $img_dir . '/' . $item['file'];
    if (file_exists($path)) {
        continue;
    }
    
    $w = 600;
    $h = 450;
    $im = imagecreatetruecolor($w, $h);
    
    // Background color
    $bg = imagecolorallocate($im, $item['color'][0], $item['color'][1], $item['color'][2]);
    imagefill($im, 0, 0, $bg);
    
    // Border
    $white = imagecolorallocate($im, 255, 255, 255);
    $gold = imagecolorallocate($im, 240, 200, 120);
    imagerectangle($im, 20, 20, $w - 20, $h - 20, $gold);
    imagerectangle($im, 24, 24, $w - 24, $h - 24, $gold);
    
    // Text drawing using built-in font
    $font = 5; // Built-in font size 5 (largest)
    $text1 = strtoupper($item['title']);
    $text2 = $item['sub'];
    $brand = "DAC SAN VIET NAM - DE TAI 3";
    
    // Center brand
    $x_b = ($w - (strlen($brand) * imagefontwidth(3))) / 2;
    imagestring($im, 3, $x_b, 80, $brand, $gold);
    
    // Center text1
    $x1 = ($w - (strlen($text1) * imagefontwidth($font))) / 2;
    imagestring($im, $font, $x1, 190, $text1, $white);
    
    // Center text2
    $x2 = ($w - (strlen($text2) * imagefontwidth(4))) / 2;
    imagestring($im, 4, $x2, 240, $text2, $gold);
    
    imagepng($im, $path);
    imagedestroy($im);
}

echo "Generated seed images in $img_dir successfully.\n";
