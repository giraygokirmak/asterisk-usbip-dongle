#!/bin/sh

# Değişken temizliği
CLEAN_IP=$(echo "$USB_IP" | tr -d '\r\n ')
CLEAN_BIND=$(echo "$USB_BIND" | tr -d '\r\n ')

echo "DONGLE TAKIP SISTEMI BASLATILDI ($CLEAN_IP)"

while true; do
    # ADIM 1: Huawei cihaz fiziksel olarak bağlı mı?
    if lsusb 2>/dev/null | grep "Huawei"; then
        # Huawei var, tüm ttyUSB portlarının permission'larını düzelt
        chmod 777 /dev/ttyUSB* 2>/dev/null
        sleep 30
        continue
    fi

    # ADIM 2: Cihaz yoksa, hayalet port var mı kontrol et
    GHOST_PORT=$(usbip port 2>/dev/null | grep "<In Use>" | sed 's/.*Port \([0-9]\{1,2\}\):.*/\1/' | head -n 1)

    if [ -n "$GHOST_PORT" ]; then
        echo "Cihaz kopmuş ama port meşgul görünüyor. Temizleniyor (Port: $GHOST_PORT)..."
        usbip detach -p "$GHOST_PORT" 2>/dev/null
        sleep 2
    fi

    # ADIM 3: Bağlanmayı dene
    echo "Cihaz bulunamadı. $CLEAN_IP üzerinden bağlanılıyor..."
    usbip attach -r "$CLEAN_IP" -b "$CLEAN_BIND" > /dev/null 2>&1
    
    sleep 5

    # ADIM 4: Bağlantı sonrası permission ayarla
    if lsusb 2>/dev/null | grep -qi "huawei"; then
        echo "Bağlantı başarılı! İzinler ayarlanıyor..."
        chmod 777 /dev/ttyUSB* 2>/dev/null
        asterisk -rx "dongle reload now" > /dev/null 2>&1
    fi

    sleep 10
done
