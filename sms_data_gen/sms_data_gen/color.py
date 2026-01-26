VALID_SMS_RGB_VALUES = {0, 85, 170, 255}

def is_sms_color(color):
    r, g, b = color[:3]
    return all(c in VALID_SMS_RGB_VALUES for c in (r, g, b))