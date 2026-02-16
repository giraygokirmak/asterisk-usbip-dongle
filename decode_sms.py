#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import base64

# GSM 7-bit to Unicode mapping
GSM7_BASIC = [
    '@', '£', '$', '¥', 'è', 'é', 'ù', 'ì', 'ò', 'Ç', '\n', 'Ø', 'ø', '\r', 'Å', 'å',
    'Δ', '_', 'Φ', 'Γ', 'Λ', 'Ω', 'Π', 'Ψ', 'Σ', 'Θ', 'Ξ', '\x1b', 'Æ', 'æ', 'ß', 'É',
    ' ', '!', '"', '#', '¤', '%', '&', "'", '(', ')', '*', '+', ',', '-', '.', '/',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', '=', '>', '?',
    '¡', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Ä', 'Ö', 'Ñ', 'Ü', '§',
    '¿', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o',
    'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'ä', 'ö', 'ñ', 'ü', 'à'
]

# Turkish National Language Single Shift Table
GSM7_TURKISH_SHIFT = {
    0x0A: '\f',   # Form feed
    0x14: '^',    # Circumflex
    0x28: '{',    # Left curly bracket
    0x29: '}',    # Right curly bracket
    0x2F: '\\',   # Reverse solidus (Backslash)
    0x3C: '[',    # Left square bracket
    0x3D: '~',    # Tilde
    0x3E: ']',    # Right square bracket
    0x40: '|',    # Vertical bar
    0x47: 'Ğ',    # Latin capital letter G with breve
    0x49: 'İ',    # Latin capital letter I with dot above
    0x53: 'Ş',    # Latin capital letter S with cedilla
    0x63: 'ç',    # Latin small letter c with cedilla
    0x65: 'ğ',    # Latin small letter g with breve
    0x69: 'ı',    # Latin small letter dotless i
    0x73: 'ş',    # Latin small letter s with cedilla
}

def unpack_septets(data, padding=0, length=None):
    """Unpack 7-bit septets from octets"""
    bits = []
    for byte in data:
        bits.extend([int(b) for b in format(byte, '08b')[::-1]])  # LSB first
    
    # Skip padding bits
    bits = bits[padding:]
    
    # Extract septets
    septets = []
    for i in range(0, len(bits), 7):
        if length is not None and len(septets) >= length:
            break
        if i + 7 <= len(bits):
            septet_bits = bits[i:i+7]
            value = sum(bit << idx for idx, bit in enumerate(septet_bits))
            septets.append(value)
    
    return septets

def decode_gsm7(data, padding=0, length=None, turkish=False):
    """Decode GSM 7-bit encoded data"""
    septets = unpack_septets(data, padding, length)
    
    result = []
    escape = False
    
    for septet in septets:
        if septet == 0x00:  # Null - end of message
            break
        elif escape:
            # Extended character
            if turkish and septet in GSM7_TURKISH_SHIFT:
                result.append(GSM7_TURKISH_SHIFT[septet])
            elif septet < len(GSM7_BASIC):
                result.append(GSM7_BASIC[septet])
            else:
                result.append('?')
            escape = False
        elif septet == 0x1B:  # Escape to extension table
            escape = True
        else:
            # Basic character
            if septet < len(GSM7_BASIC):
                result.append(GSM7_BASIC[septet])
            else:
                result.append('?')
    
    return ''.join(result)

def parse_pdu(pdu_hex):
    """Parse SMS-DELIVER PDU"""
    pos = 0
    
    # SMSC
    smsc_len = int(pdu_hex[pos:pos+2], 16)
    pos += 2 + (smsc_len * 2)
    
    # First octet
    fo = int(pdu_hex[pos:pos+2], 16)
    pos += 2
    udhi = bool(fo & 0x40)
    
    # Originating address
    oa_len = int(pdu_hex[pos:pos+2], 16)
    pos += 2
    oa_type = int(pdu_hex[pos:pos+2], 16)
    pos += 2
    oa_digits = (oa_len + 1) // 2
    oa_hex = pdu_hex[pos:pos+(oa_digits*2)]
    pos += oa_digits * 2
    
    # PID
    pos += 2
    
    # DCS
    dcs = int(pdu_hex[pos:pos+2], 16)
    pos += 2
    
    # SCTS (timestamp)
    pos += 14
    
    # UDL
    udl = int(pdu_hex[pos:pos+2], 16)
    pos += 2
    
    # UD (User Data)
    ud_hex = pdu_hex[pos:]
    ud_bytes = bytes.fromhex(ud_hex)
    
    # Parse UDH if present
    padding = 0
    turkish = False
    ud_start = 0
    
    if udhi:
        udhl = ud_bytes[0]
        udh_end = udhl + 1
        
        # Look for National Language Single Shift (IEI 0x24)
        i = 1
        while i < udh_end:
            iei = ud_bytes[i]
            iedl = ud_bytes[i+1]
            if iei == 0x24:  # Turkish Single Shift Table
                turkish = True
            i += 2 + iedl
        
        # Calculate padding
        udh_bits = udh_end * 8
        padding = 7 - (udh_bits % 7) if udh_bits % 7 else 0
        ud_start = udh_end
    
    # Decode message
    if dcs & 0x04:  # 8-bit
        message = ud_bytes[ud_start:].decode('latin-1', errors='replace')
    elif (dcs & 0x0C) == 0x08:  # UCS-2
        message = ud_bytes[ud_start:].decode('utf-16-be', errors='replace')
    else:  # 7-bit (default)
        message = decode_gsm7(ud_bytes[ud_start:], padding, udl - (udh_end if udhi else 0), turkish)
    
    return message

def main():
    if len(sys.argv) < 2:
        print("", file=sys.stderr)
        return
    
    try:
        # Decode base64 CMGR
        cmgr_b64 = sys.argv[1]
        cmgr_raw = base64.b64decode(cmgr_b64).decode('utf-8', errors='ignore')
        
        # Extract PDU (second line)
        lines = [l.strip() for l in cmgr_raw.split('\n') if l.strip()]
        pdu_hex = lines[1] if len(lines) > 1 else lines[0]
        
        # Parse and decode
        message = parse_pdu(pdu_hex)
        
        # Output UTF-8 message
        print(message, end='')
        
    except Exception as e:
        print(f"", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
