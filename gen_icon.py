from PIL import Image, ImageDraw, ImageFont
import os

def create_ai_icon(size=512):
    """创建带AI标识的文字创意工坊图标"""
    # 渐变背景
    temp = Image.new('RGB', (size, size))
    temp_draw = ImageDraw.Draw(temp)
    for y in range(size):
        t = y / size
        r = int(255 * (1 - t) + 236 * t)
        g = int(45 * (1 - t) + 64 * t)
        b = int(85 * (1 - t) + 87 * t)
        temp_draw.line([(0, y), (size, y)], fill=(r, g, b))

    # 圆形mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, size-1, size-1], fill=255)

    # 合并
    img = Image.new('RGBA', (size, size))
    img.paste(temp, (0, 0), mask)

    draw = ImageDraw.Draw(img)

    # 中心笔尖图标
    pen_size = size // 5
    cx, cy = size // 2, size // 2 - pen_size // 6

    # 笔身（白色梯形）
    draw.polygon([
        (cx - pen_size//4, cy - pen_size//3),
        (cx + pen_size//4, cy - pen_size//3),
        (cx + pen_size//8, cy + pen_size//4),
        (cx - pen_size//8, cy + pen_size//4)
    ], fill='white')

    # 笔尖金属部分（灰色）
    draw.polygon([
        (cx - pen_size//8, cy + pen_size//4),
        (cx + pen_size//8, cy + pen_size//4),
        (cx, cy + pen_size//2)
    ], fill='#E5E7EB')

    # 笔尖（深色）
    draw.polygon([
        (cx - pen_size//16, cy + pen_size//2 - 5),
        (cx + pen_size//16, cy + pen_size//2 - 5),
        (cx, cy + pen_size//2 + 15)
    ], fill='#1A1A2E')

    # AI标签圆圈（右上角）
    ai_r = size // 10
    ax, ay = size - size//5, size//5
    draw.ellipse([ax-ai_r, ay-ai_r, ax+ai_r, ay+ai_r], fill='#1A1A2E')
    draw.ellipse([ax-ai_r+4, ay-ai_r+4, ax+ai_r-4, ay+ai_r-4], fill='#2D2D3A')

    # AI文字
    try:
        font_small = ImageFont.truetype("arial.ttf", size // 12)
    except:
        font_small = ImageFont.load_default()
    draw.text((ax - size//25, ay - size//20), "AI", fill='white', font=font_small)

    # sparkle装饰（四个方向短线）
    sparkle_positions = [
        (cx - pen_size//2, cy - pen_size//3),
        (cx + pen_size//2 + 10, cy - pen_size//6),
        (cx - pen_size//3, cy + pen_size//3),
    ]
    for sx, sy in sparkle_positions:
        s = size // 30
        draw.line([(sx, sy-s), (sx, sy+s)], fill='white', width=2)
        draw.line([(sx-s, sy), (sx+s, sy)], fill='white', width=2)

    out = os.path.join(os.path.dirname(__file__), 'icon.png')
    img.save(out, 'PNG')
    print(f"Icon saved: {out}")

create_ai_icon(512)
