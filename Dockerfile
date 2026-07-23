ARG ASTERISK_BASE_IMAGE=andrius/asterisk@sha256:4cfb208f877b45e88115b35140b1edba06e1374e9bce4b6f5e55a84e60254b92
FROM ${ASTERISK_BASE_IMAGE}

USER root

# Fail2ban ve iptables ekleniyor
RUN apt-get update && \
    apt-get install -y \
	usbip \
	hwdata \
    coreutils \
    procps \
    util-linux \
    iputils-ping \
    fail2ban \
    iptables \
    gettext-base \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libusb-1.0-0-dev \
    libasound2-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libssl-dev \
    libxml2-dev \
    libsrtp2-dev \
    libedit-dev \
    libjansson-dev \
    uuid-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Get Asterisk version and download matching source
WORKDIR /tmp
RUN ASTERISK_VERSION=$(asterisk -V 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n1) && \
    echo "Detected Asterisk version: $ASTERISK_VERSION" && \
    echo "Downloading Asterisk $ASTERISK_VERSION source..." && \
    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz || \
    wget https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz || \
    { echo "Could not download exact version, trying latest from series"; \
      MAJOR_VERSION=$(echo $ASTERISK_VERSION | cut -d. -f1); \
      wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${MAJOR_VERSION}-current.tar.gz && \
      mv asterisk-${MAJOR_VERSION}-current.tar.gz asterisk-${ASTERISK_VERSION}.tar.gz; \
    } && \
    tar -xzf asterisk-${ASTERISK_VERSION}.tar.gz && \
    EXTRACTED_DIR=$(tar -tzf asterisk-${ASTERISK_VERSION}.tar.gz | head -1 | cut -f1 -d"/") && \
    mv ${EXTRACTED_DIR} /usr/src/asterisk && \
    echo "Asterisk source extracted to /usr/src/asterisk"

# Configure Asterisk source and generate necessary headers
WORKDIR /usr/src/asterisk
RUN echo "Configuring Asterisk source and generating headers..." && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make include/asterisk/buildopts.h && \
    echo "Asterisk headers generated successfully"

# Clone and build chan_dongle with configured Asterisk headers
WORKDIR /tmp/build
ARG CHAN_DONGLE_COMMIT=0b7a6a49b3a3164da84090a7d73536643ce4fb56
RUN git clone https://github.com/giraygokirmak/asterisk-chan-dongle.git && \
    cd asterisk-chan-dongle && \
    git checkout "$CHAN_DONGLE_COMMIT" && \
    ./bootstrap && \
    ASTERISK_VERSION=$(asterisk -V 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n1) && \
    echo "Configuring chan_dongle for Asterisk $ASTERISK_VERSION..." && \
    ./configure \
        --with-astversion=$ASTERISK_VERSION \
        --with-asterisk=/usr/src/asterisk/include && \
    echo "Building chan_dongle..." && \
    make

# Find and replace the original chan_dongle.so
RUN ORIGINAL_SO=$(find /usr -name "chan_dongle.so" 2>/dev/null | head -n 1) && \
    if [ -n "$ORIGINAL_SO" ]; \
    then \
        echo "Found original chan_dongle.so at: $ORIGINAL_SO" && \
        cp "$ORIGINAL_SO" "${ORIGINAL_SO}.backup" && \
        cp /tmp/build/asterisk-chan-dongle/chan_dongle.so "$ORIGINAL_SO" && \
        chmod 755 "$ORIGINAL_SO" && \
        echo "Replaced chan_dongle.so successfully"; \
    else \
        echo "Original chan_dongle.so not found, installing to default location" && \
        mkdir -p /usr/lib/asterisk/modules && \
        cp /tmp/build/asterisk-chan-dongle/chan_dongle.so /usr/lib/asterisk/modules/ && \
        chmod 755 /usr/lib/asterisk/modules/chan_dongle.so && \
        echo "Installed chan_dongle.so to /usr/lib/asterisk/modules/"; \
    fi

# Clean up
RUN apt-get purge -y \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    wget \
    && apt-get autoremove -y \
    && rm -rf /tmp/build /tmp/asterisk-* /usr/src/asterisk

COPY jail.local /etc/fail2ban/jail.local
COPY asterisk-filter.conf /etc/fail2ban/filter.d/asterisk.conf	
COPY usbip.sh /usr/bin/usbip.sh
COPY asterisk-entrypoint.sh /usr/bin/asterisk-entrypoint.sh
RUN chmod 755 /usr/bin/usbip.sh /usr/bin/asterisk-entrypoint.sh
RUN echo "security.log => security" >> /etc/asterisk/logger.conf

WORKDIR /
