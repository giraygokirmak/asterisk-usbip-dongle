#!/bin/sh

CLEAN_IP=$(echo "$USB_IP" | tr -d '\r\n ')
CLEAN_BIND=$(echo "$USB_BIND" | tr -d '\r\n ')

echo "DONGLE TAKIP SISTEMI BASLATILDI ($CLEAN_IP)"

# Huawei cihazına ait ttyUSB portlarını bul (Vendor ID: 12d1)
find_huawei_ports() {
    for tty in /sys/class/tty/ttyUSB*/device/../../; do
        if [ -f "$tty/idVendor" ]; then
            vendor=$(cat "$tty/idVendor" 2>/dev/null)
            if [ "$vendor" = "12d1" ]; then
                # Bu Huawei cihazı, ttyUSB portlarını bul
                find "$tty" -name "ttyUSB*" 2>/dev/null | while read ttypath; do
                    basename "$ttypath"
                done
            fi
        fi
    done | sort -u
}

# Portları device path olarak döndür
get_huawei_devices() {
    find_huawei_ports | while read port; do
        echo "/dev/$port"
    done
}

# Huawei portları var mı?
check_huawei_exists() {
    PORTS=$(get_huawei_devices)
    [ -n "$PORTS" ]
    return $?
}

while true; do
    # ADIM 1: Huawei cihaz var mı kontrol et
    if check_huawei_exists; then
        # Huawei var, portlarının permission'larını düzelt
        PORTS=$(get_huawei_devices)
        chmod 777 $PORTS 2>/dev/null
        sleep 30
        continue
    fi

    # ADIM 2: Cihaz yok, hayalet port temizle
    echo "Huawei cihaz bulunamadı, yeniden bağlanılacak..."
    
    GHOST_PORT=$(usbip port 2>/dev/null | grep "<In Use>" | sed 's/.*Port \([0-9]\{1,2\}\):.*/\1/' | head -n 1)

    if [ -n "$GHOST_PORT" ]; then
        echo "Hayalet port temizleniyor (Port: $GHOST_PORT)..."
        usbip detach -p "$GHOST_PORT" 2>/dev/null
        sleep 2
    fi

    # ADIM 3: Bağlanmayı dene
    echo "Cihaz bulunamadı. $CLEAN_IP üzerinden bağlanılıyor..."
    usbip attach -r "$CLEAN_IP" -b "$CLEAN_BIND" > /dev/null 2>&1
    
    sleep 5

    # ADIM 4: Bağlantı sonrası kontrol
    if check_huawei_exists; then
        PORTS=$(get_huawei_devices)
        echo "Bağlantı başarılı! Huawei portları:"
        echo "$PORTS"
        
        chmod 777 $PORTS 2>/dev/null
        asterisk -rx "dongle reload gracefully" > /dev/null 2>&1
    fi

    sleep 10
done
