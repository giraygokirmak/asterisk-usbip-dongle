#!/bin/sh

# Değişken temizliği
CLEAN_IP=$(echo "$USB_IP" | tr -d '\r\n ')
CLEAN_BIND=$(echo "$USB_BIND" | tr -d '\r\n ')

echo "DONGLE TAKIP SISTEMI BASLATILDI ($CLEAN_IP)"

while true; do
    # ADIM 1: Cihaz node'u zaten var mı?
    # Eğer /dev/ttyUSB2 (data portu) varsa, her şey yolundadır, dokunma.
    if [ -e /dev/ttyUSB2 ]; then
        # Cihaz var, sadece bekle. usbip komutlarını çalıştırma!
        sleep 30
        continue
    fi

    # ADIM 2: Cihaz yoksa, önce sistemde asılı kalmış hayalet (ghost) port var mı bak.
    # Bu kontrolü sadece cihaz yokken yapıyoruz ki 'fopen' hatalarını azaltalım.
    GHOST_PORT=$(usbip port 2>/dev/null | grep "<In Use>" | sed 's/.*Port \([0-9]\{1,2\}\):.*/\1/' | head -n 1)

    if [ -n "$GHOST_PORT" ]; then
        echo "Cihaz kopmus ama port meşgul görünüyor. Temizleniyor (Port: $GHOST_PORT)..."
        usbip detach -p "$GHOST_PORT" 2>/dev/null
        sleep 2
    fi

    # ADIM 3: Bağlanmayı dene
    echo "Cihaz bulunamadı. $CLEAN_IP üzerinden bağlanılıyor..."
    usbip attach -r "$CLEAN_IP" -b "$CLEAN_BIND" > /dev/null 2>&1
    
    # Bağlanma denemesinden sonra bekle
    sleep 5

    # ADIM 4: Eğer başarıyla bağlandıysa izinleri ayarla ve Asterisk'e haber ver
    if [ -e /dev/ttyUSB2 ]; then
        echo "Bağlantı başarılı! İzinler ayarlanıyor..."
        chmod 777 /dev/ttyUSB*
        # Asterisk içindeki dongle modülünü yenile (isteğe bağlı)
        asterisk -rx "dongle reload now" > /dev/null 2>&1
    fi

    sleep 10
done