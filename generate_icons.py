#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成创意写作应用的图标
包含圆角矩形背景、AI标识、文学艺术风格
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_rounded_rectangle(width, height, radius, fill_color):
    """创建圆角矩形"""
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # 绘制圆角矩形
    draw.rounded_rectangle(
        [(0, 0), (width-1, height-1)],
        radius=radius,
        fill=fill_color
    )
    
    return image

def create_gradient_background(width, height):
    """创建渐变背景（蓝紫色）"""
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # 渐变色：从左上到右下
    color1 = (102, 126, 234)  # #667EEA
    color2 = (118, 75, 162)   # #764BA2
    
    for y in range(height):
        for x in range(width):
            # 计算渐变比例
            ratio = (x + y) / (width + height)
            r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
            g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
            b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
            image.putpixel((x, y), (r, g, b, 255))
    
    return image

def draw_feather_pen(draw, x, y, size, color):
    """绘制羽毛笔"""
    # 笔杆
    pen_width = size // 20
    draw.line(
        [(x, y), (x + size, y + size)],
        fill=color,
        width=pen_width
    )
    
    # 笔尖
    tip_size = size // 8
    draw.polygon(
        [
            (x + size, y + size),
            (x + size - tip_size, y + size + tip_size//2),
            (x + size + tip_size//2, y + size - tip_size)
        ],
        fill=color
    )
    
    # 羽毛
    feather_points = []
    for i in range(5):
        offset = i * size // 10
        feather_points.extend([
            (x + offset, y + offset),
            (x + offset - size//8, y + offset + size//16),
            (x + offset, y + offset)
        ])
    
    if len(feather_points) >= 3:
        draw.polygon(feather_points[:3], fill=color)

def draw_ai_chip(draw, x, y, size, color):
    """绘制AI芯片标识"""
    # 芯片主体
    chip_size = size
    draw.rectangle(
        [(x, y), (x + chip_size, y + chip_size)],
        outline=color,
        width=size // 10
    )
    
    # 内部电路
    inner_margin = size // 5
    draw.rectangle(
        [(x + inner_margin, y + inner_margin), 
         (x + chip_size - inner_margin, y + chip_size - inner_margin)],
        outline=color,
        width=size // 20
    )
    
    # AI文字
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size // 2)
    except:
        font = ImageFont.load_default()
    
    text = "AI"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = x + (chip_size - text_width) // 2
    text_y = y + (chip_size - text_height) // 2
    draw.text((text_x, text_y), text, fill=color, font=font)

def create_app_icon(output_path, size=1024):
    """创建应用图标"""
    # 创建圆角矩形背景
    radius = size // 6
    icon = create_rounded_rectangle(size, size, radius, (255, 255, 255, 0))
    
    # 添加渐变背景
    gradient = create_gradient_background(size, size)
    icon = Image.alpha_composite(icon, gradient)
    
    draw = ImageDraw.Draw(icon)
    
    # 绘制羽毛笔（左上到右下）
    pen_x = int(size * 0.2)
    pen_y = int(size * 0.2)
    pen_size = int(size * 0.4)
    draw_feather_pen(draw, pen_x, pen_y, pen_size, (255, 255, 255, 200))
    
    # 绘制AI芯片（右下角）
    chip_size = int(size * 0.25)
    chip_x = int(size * 0.6)
    chip_y = int(size * 0.6)
    draw_ai_chip(draw, chip_x, chip_y, chip_size, (255, 255, 255, 230))
    
    # 保存
    icon.save(output_path, 'PNG')
    print(f"✓ 应用图标已生成: {output_path}")

def create_template_icon(name, emoji, output_path, size=256):
    """创建模板图标"""
    # 创建圆角矩形背景
    radius = size // 4
    icon = create_rounded_rectangle(size, size, radius, (255, 255, 255, 0))
    
    # 添加渐变背景（使用不同颜色）
    gradient = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(gradient)
    draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=radius,
        fill=(102, 126, 234, 255)
    )
    
    icon = Image.alpha_composite(icon, gradient)
    draw = ImageDraw.Draw(icon)
    
    # 绘制emoji
    try:
        # 尝试使用系统字体
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size // 2)
    except:
        font = ImageFont.load_default()
    
    # 居中绘制emoji
    bbox = draw.textbbox((0, 0), emoji, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    draw.text((x, y), emoji, fill=(255, 255, 255, 255), font=font)
    
    # 保存
    icon.save(output_path, 'PNG')
    print(f"✓ 模板图标已生成: {name} -> {output_path}")

def main():
    """主函数"""
    # 创建输出目录
    output_dir = "/workspace/WritingApp/entry/src/main/resources/base/media"
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成应用图标
    create_app_icon(f"{output_dir}/app_icon.png", 1024)
    
    # 生成模板图标
    templates = [
        ("短剧剧本", "🎬"),
        ("漫才", "🎭"),
        ("英雄之旅", "⚔️"),
        ("情感拉扯", "💫"),
        ("悬疑推理", "🔍"),
        ("素描喜剧", "✏️"),
        ("短视频脚本", "📱"),
        ("剧本杀", "🕵️"),
        ("五幕剧", "🎪"),
        ("长篇小说大纲", "📚"),
        ("人物设定表", "👤"),
        ("章节规划", "📝"),
        ("世界观构建", "🌍"),
        ("剧情大纲", "🎯"),
    ]
    
    for name, emoji in templates:
        filename = name.replace(" ", "_").lower()
        create_template_icon(name, emoji, f"{output_dir}/template_{filename}.png", 256)
    
    print("\n✓ 所有图标生成完成！")

if __name__ == "__main__":
    main()
