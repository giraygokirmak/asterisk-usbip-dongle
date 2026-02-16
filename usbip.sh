#!/bin/sh

CLEAN_IP=$(echo "$USB_IP" | tr -d '\r\n ')

echo "DONGLE TAKIP SISTEMI BASLATILDI (Hedef IP: $CLEAN_IP)"

# Uzaktaki sunucudan Huawei cihazın BIND ID'sini otomatik bul
find_remote_bind_id() {
    # usbip list çıktısında 12d1 (Huawei) içeren satırı bul ve başındaki busid'yi al
    usbip list -r "$CLEAN_IP" 2>/dev/null | grep "12d1:" | awk '{print $1}' | tr -d ' ' | head -n 1
}

# Huawei cihazına ait yerel ttyUSB portlarını bul
find_huawei_ports() {
    for tty in /sys/class/tty/ttyUSB*/device/../../; do
        if [ -f "$tty/idVendor" ]; then
            vendor=$(cat "$tty/idVendor" 2>/dev/null)
            if [ "$vendor" = "12d1" ]; then
                find "$tty" -name "ttyUSB*" 2>/dev/null | while read ttypath; do
                    basename "$ttypath"
                done
            fi
        fi
    done | sort -u
}

get_huawei_devices() {
    find_huawei_ports | while read port; do
        echo "/dev/$port"
    done
}

check_huawei_exists() {
    PORTS=$(get_huawei_devices)
    [ -n "$PORTS" ]
    return $?
}

while true; do
    # ADIM 1: Yerelde cihaz var mı kontrol et
    if check_huawei_exists; then
        PORTS=$(get_huawei_devices)
        chmod 777 $PORTS 2>/dev/null
        sleep 30
        continue
    fi

    echo "Huawei cihaz bulunamadı, yeniden bağlanılacak..."
    
    # ADIM 2: Hayalet port temizle
    GHOST_PORT=$(usbip port 2>/dev/null | grep "<In Use>" | sed 's/.*Port \([0-9]\{1,2\}\):.*/\1/' | head -n 1)
    if [ -n "$GHOST_PORT" ]; then
        echo "Hayalet port temizleniyor (Port: $GHOST_PORT)..."
        usbip detach -p "$GHOST_PORT" 2>/dev/null
        sleep 2
    fi

    # ADIM 3: Dinamik BIND ID Al ve Bağlan
    DYNAMIC_BIND=$(find_remote_bind_id)

    if [ -z "$DYNAMIC_BIND" ]; then
        echo "HATA: Uzak sunucuda ($CLEAN_IP) Huawei cihaz bulunamadı! 10sn sonra tekrar denenecek."
        sleep 10
        continue
    fi

    echo "Cihaz bulundu. ID: $DYNAMIC_BIND üzerinden bağlanılıyor..."
    usbip attach -r "$CLEAN_IP" -b "$DYNAMIC_BIND" > /dev/null 2>&1
    
    sleep 5

    # ADIM 4: Bağlantı sonrası kontrol
    if check_huawei_exists; then
        PORTS=$(get_huawei_devices)
        echo "Bağlantı başarılı! Cihaz ID: $DYNAMIC_BIND | Portlar: $PORTS"
        
        chmod 777 $PORTS 2>/dev/null
        asterisk -rx "dongle reload gracefully" > /dev/null 2>&1
    fi

    sleep 10
done
