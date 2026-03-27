#!/usr/bin/env python3
"""
Generate page mockup images for analytics heatmap visualization.
Creates PNG images representing each page of the app with accurate layouts.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import glob

# Create directory for page images
#output_dir = 'app/static/analytics'
output_dir = 'static/analytics'
os.makedirs(output_dir, exist_ok=True)

# Clean up old page images before regenerating
print("Cleaning up old page mockup images...")
old_images = glob.glob(os.path.join(output_dir, '*.png'))
for old_img in old_images:
    try:
        os.remove(old_img)
        print(f"🗑️  Removed {os.path.basename(old_img)}")
    except Exception as e:
        print(f"⚠️  Could not remove {os.path.basename(old_img)}: {e}")
print()

# Canvas size (matches typical viewport)
WIDTH = 1200
HEIGHT = 800

# Colors (matching design system tokens in tokens.css)
BG_DARK = '#111210'         # --color-bg
BG_MEDIUM = '#1B1B1B'       # --color-surface
BG_LIGHT = '#242422'        # --color-elevated
BORDER = '#2E2E2A'          # --color-border
BORDER_HOVER = '#3A3A36'    # --color-border-hover
ACCENT = '#595F39'          # --color-accent (Muted Moss)
ACCENT_HOVER = '#6B7244'    # --color-accent-hover
TEXT = '#E4E4DE'             # --color-text
TEXT_MUTED = '#C4C5BA'       # --color-text-muted
TEXT_DIM = '#7A7B72'         # --color-text-dim
EBAY_BLUE = '#00BFFF'       # --color-ebay
WHATNOT_MAGENTA = '#FF00FF'  # --color-whatnot
GREEN = '#5C8A5C'           # --color-success
RED = '#C45C5C'             # --color-danger


def hex_to_rgb(hex_color):
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_base_page(title="Page"):
    """Create base page template with accurate header and navigation."""
    img = Image.new('RGB', (WIDTH, HEIGHT), hex_to_rgb(BG_DARK))
    draw = ImageDraw.Draw(img)

    # Header bar (matches actual app)
    draw.rectangle([0, 0, WIDTH, 80], fill=hex_to_rgb(BG_LIGHT), outline=hex_to_rgb(BORDER), width=1)

    # Logo (comic book icon - yellow square with stylized design)
    logo_x, logo_y = 30, 15
    draw.rectangle([logo_x, logo_y, logo_x + 50, logo_y + 50], fill=hex_to_rgb(ACCENT))
    # Add comic "pages" effect
    draw.line([logo_x + 15, logo_y, logo_x + 15, logo_y + 50], fill=hex_to_rgb(BG_DARK), width=2)
    draw.line([logo_x + 35, logo_y, logo_x + 35, logo_y + 50], fill=hex_to_rgb(BG_DARK), width=2)

    # Bottom navigation bar (8 icons)
    draw.rectangle([0, HEIGHT - 80, WIDTH, HEIGHT], fill=hex_to_rgb(BG_MEDIUM), outline=hex_to_rgb(BORDER), width=1)

    # Bottom nav items with icons (matching actual nav)
    nav_items = [
        ('⚡', 100),   # Home
        ('📊', 230),   # Browse
        ('➕', 360),   # Add
        ('🗑️', 490),  # Trash
        ('💰', 620),   # Prices
        ('📈', 750),   # Analytics
        ('👤', 880),   # Account
        ('🚪', 1010),  # Logout
    ]

    for icon, x in nav_items:
        # Icon circle/button
        draw.rectangle([x - 20, HEIGHT - 60, x + 20, HEIGHT - 20],
                      fill=hex_to_rgb(BG_LIGHT), outline=hex_to_rgb(BORDER), width=1)

    return img, draw

def create_browse_page():
    """Create browse/comic list page mockup - matches actual grid layout."""
    img, draw = create_base_page("Browse Comics")

    # Filter buttons row (All Comics, For Sale, eBay, WhatNot, WhatNot Givys)
    filters = [
        ('All Comics', 40, BG_LIGHT),
        ('For Sale', 200, ACCENT),  # Active/selected
        ('eBay', 340, BG_LIGHT),
        ('WhatNot', 460, BG_LIGHT),
        ('WhatNot Givys', 590, BG_LIGHT),
    ]

    for label, x, color in filters:
        btn_width = 140
        draw.rectangle([x, 100, x + btn_width, 135],
                      fill=hex_to_rgb(color),
                      outline=hex_to_rgb(BORDER), width=2)

    # Comic cards grid - 3 columns, 2 rows (matches actual browse page)
    card_width = 360
    card_height = 260
    spacing = 30
    start_x = 40
    start_y = 160

    for row in range(2):
        for col in range(3):
            x = start_x + (col * (card_width + spacing))
            y = start_y + (row * (card_height + spacing))

            # Card container with border
            draw.rectangle([x, y, x + card_width, y + card_height],
                          fill=hex_to_rgb(BG_LIGHT),
                          outline=hex_to_rgb(BORDER), width=2)

            # Image/thumbnail area (top 70% of card)
            img_height = 180
            draw.rectangle([x + 10, y + 10, x + card_width - 10, y + img_height],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)

            # SKU badge (bottom left)
            sku_num = 1001 + (row * 3) + col
            draw.rectangle([x + 15, y + img_height + 10, x + 75, y + img_height + 32],
                          fill=hex_to_rgb(ACCENT),
                          outline=hex_to_rgb(BORDER), width=1)

            # Status indicators (eBay blue circle, WhatNot magenta circle)
            # eBay indicator
            draw.ellipse([x + 85, y + img_height + 12, x + 100, y + img_height + 27],
                        fill=hex_to_rgb(EBAY_BLUE))
            # WhatNot indicator
            draw.ellipse([x + 110, y + img_height + 12, x + 125, y + img_height + 27],
                        fill=hex_to_rgb(WHATNOT_MAGENTA))

            # Action buttons at bottom
            btn_y = y + img_height + 45
            # View/Edit button
            draw.rectangle([x + 15, btn_y, x + 170, btn_y + 30],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)
            # Delete button
            draw.rectangle([x + 185, btn_y, x + card_width - 15, btn_y + 30],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)

    return img

def create_add_page():
    """Create add/edit comic page mockup - matches two-column layout."""
    img, draw = create_base_page("Add/Edit Comic")

    # LEFT COLUMN: Image upload area
    left_x = 40
    left_width = 400

    # Main image upload box
    draw.rectangle([left_x, 100, left_x + left_width, 520],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    # Large preview area
    draw.rectangle([left_x + 15, 120, left_x + left_width - 15, 420],
                  fill=hex_to_rgb(BG_MEDIUM),
                  outline=hex_to_rgb(BORDER), width=1)

    # Thumbnail strip (4 thumbnails)
    thumb_y = 440
    thumb_size = 85
    for i in range(4):
        thumb_x = left_x + 20 + (i * 95)
        draw.rectangle([thumb_x, thumb_y, thumb_x + thumb_size, thumb_y + thumb_size],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

    # Action buttons section (below image area, above form)
    actions_y = 540
    btn_width = 180
    btn_height = 36
    btn_gap = 12

    # First row: Google Lens and Delete Comic
    draw.rectangle([left_x, actions_y, left_x + btn_width, actions_y + btn_height],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=1)
    draw.rectangle([left_x + btn_width + btn_gap, actions_y, left_x + btn_width * 2 + btn_gap, actions_y + btn_height],
                  fill=hex_to_rgb(RED),
                  outline=hex_to_rgb(BORDER), width=1)

    # Second row: Google Image Search and Search eBay
    actions_y2 = actions_y + btn_height + 8
    draw.rectangle([left_x, actions_y2, left_x + btn_width, actions_y2 + btn_height],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=1)
    draw.rectangle([left_x + btn_width + btn_gap, actions_y2, left_x + btn_width * 2 + btn_gap, actions_y2 + btn_height],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=1)

    # RIGHT COLUMN: Form fields
    right_x = 470
    right_width = 690
    field_height = 50
    field_spacing = 15

    # Form fields (title, publisher, issue, grade, price, etc.)
    fields = [
        'Title',
        'Publisher',
        'Issue Number',
        'Grade/Condition',
        'Price',
        'Listing Type',
        'Description',
        'Notes',
    ]

    for i, field in enumerate(fields):
        y = 100 + (i * (field_height + field_spacing))
        draw.rectangle([right_x, y, right_x + right_width, y + field_height],
                      fill=hex_to_rgb(BG_LIGHT),
                      outline=hex_to_rgb(BORDER), width=1)

    # BOTTOM SECTION: Footer buttons
    footer_y = 640

    # Grading icon button (left side)
    draw.rectangle([40, footer_y, 120, footer_y + 50],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    # WhatNot menu button
    draw.rectangle([680, footer_y, 820, footer_y + 50],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    # eBay menu button
    draw.rectangle([840, footer_y, 980, footer_y + 50],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    # Save button (green)
    draw.rectangle([1000, footer_y, 1160, footer_y + 50],
                  fill=hex_to_rgb(GREEN),
                  outline=hex_to_rgb(BORDER), width=2)

    return img

def create_home_page():
    """Create home/landing/dashboard page mockup."""
    img, draw = create_base_page("Dashboard")

    # Top stats row (4 cards)
    stats = [
        ('Total Comics', 40),
        ('For Sale', 340),
        ('eBay Listed', 640),
        ('Disk Space', 940),
    ]

    for label, x in stats:
        # Stat card
        draw.rectangle([x, 100, x + 270, 220],
                      fill=hex_to_rgb(BG_LIGHT),
                      outline=hex_to_rgb(BORDER), width=2)
        # Value area (bottom half - yellow accent)
        draw.rectangle([x + 10, 170, x + 260, 210],
                      fill=hex_to_rgb(ACCENT),
                      outline=hex_to_rgb(BORDER), width=1)

    # Action buttons grid (3x2)
    actions = [
        ('Add Comic', 40, 250, ACCENT),
        ('Browse Comics', 430, 250, BG_LIGHT),
        ('Price Lookup', 820, 250, BG_LIGHT),
        ('eBay Listings', 40, 420, BG_LIGHT),
        ('Export Comics', 430, 420, BG_LIGHT),
        ('Snapshots', 820, 420, BG_LIGHT),
    ]

    for label, x, y, color in actions:
        draw.rectangle([x, y, x + 360, y + 150],
                      fill=hex_to_rgb(color) if color == ACCENT else hex_to_rgb(BG_LIGHT),
                      outline=hex_to_rgb(BORDER), width=2)
        # Icon/title area at top
        draw.rectangle([x + 10, y + 10, x + 350, y + 60],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

    # System status bar at bottom
    draw.rectangle([40, 600, 1160, 690],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)
    # Mini stats/indicators
    for i in range(4):
        x = 60 + (i * 280)
        draw.rectangle([x, 615, x + 250, 675],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

    return img

def create_account_page():
    """Create account settings page mockup."""
    img, draw = create_base_page("Account Settings")

    # Settings sections (stacked vertically)
    sections = [
        ('User Profile', 100),
        ('Default Preferences', 240),
        ('eBay Integration', 380),
        ('Danger Zone', 520),
    ]

    for label, y in sections:
        # Section container
        section_height = 120
        draw.rectangle([40, y, 1160, y + section_height],
                      fill=hex_to_rgb(BG_LIGHT),
                      outline=hex_to_rgb(BORDER), width=2)

        # Section title bar
        draw.rectangle([50, y + 10, 1150, y + 50],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

        # Form fields in section (2 columns)
        field_y = y + 65
        # Left field
        draw.rectangle([50, field_y, 590, field_y + 40],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)
        # Right field
        draw.rectangle([610, field_y, 1150, field_y + 40],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

    # Save buttons at bottom
    draw.rectangle([800, 660, 1000, 710],
                  fill=hex_to_rgb(GREEN),
                  outline=hex_to_rgb(BORDER), width=2)
    draw.rectangle([1020, 660, 1160, 710],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    return img

def create_price_lookup_page():
    """Create eBay price lookup page mockup."""
    img, draw = create_base_page("eBay Price Lookup")

    # Search bar with search button
    search_width = 850
    draw.rectangle([40, 100, 40 + search_width, 160],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)
    # Search button
    draw.rectangle([910, 100, 1160, 160],
                  fill=hex_to_rgb(ACCENT),
                  outline=hex_to_rgb(BORDER), width=2)

    # Grading scale icon button
    draw.rectangle([40, 180, 200, 230],
                  fill=hex_to_rgb(BG_LIGHT),
                  outline=hex_to_rgb(BORDER), width=2)

    # Results grid (4 columns x 2 rows)
    card_width = 275
    card_height = 200
    spacing = 20
    start_y = 260

    for row in range(2):
        for col in range(4):
            x = 40 + (col * (card_width + spacing))
            y = start_y + (row * (card_height + spacing))

            # Result card
            draw.rectangle([x, y, x + card_width, y + card_height],
                          fill=hex_to_rgb(BG_LIGHT),
                          outline=hex_to_rgb(BORDER), width=1)

            # Thumbnail image area
            draw.rectangle([x + 10, y + 10, x + card_width - 10, y + 110],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)

            # Price tag
            draw.rectangle([x + 10, y + 125, x + 100, y + 155],
                          fill=hex_to_rgb(ACCENT),
                          outline=hex_to_rgb(BORDER), width=1)

            # Condition/Grade
            draw.rectangle([x + 110, y + 125, x + card_width - 10, y + 155],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)

            # Sold date
            draw.rectangle([x + 10, y + 165, x + card_width - 10, y + 190],
                          fill=hex_to_rgb(BG_MEDIUM),
                          outline=hex_to_rgb(BORDER), width=1)

    return img

def create_trash_page():
    """Create trash/deleted items page mockup."""
    img, draw = create_base_page("Trash (Deleted Items)")

    # Action buttons at top
    # Restore All (green)
    draw.rectangle([40, 100, 300, 155],
                  fill=hex_to_rgb(GREEN),
                  outline=hex_to_rgb(BORDER), width=2)
    # Empty Trash (red)
    draw.rectangle([320, 100, 580, 155],
                  fill=hex_to_rgb(RED),
                  outline=hex_to_rgb(BORDER), width=2)

    # Trash items list (6 items)
    item_height = 90
    start_y = 180

    for i in range(6):
        y = start_y + (i * (item_height + 10))

        # Item container
        draw.rectangle([40, y, 1160, y + item_height],
                      fill=hex_to_rgb(BG_LIGHT),
                      outline=hex_to_rgb(BORDER), width=1)

        # Thumbnail
        draw.rectangle([50, y + 10, 140, y + item_height - 10],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

        # Item info (SKU, title, etc.)
        # Top info line
        draw.rectangle([160, y + 15, 520, y + 40],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)
        # Bottom info line
        draw.rectangle([160, y + 50, 520, y + 75],
                      fill=hex_to_rgb(BG_MEDIUM),
                      outline=hex_to_rgb(BORDER), width=1)

        # Action buttons (right side)
        # Restore button (green)
        draw.rectangle([920, y + 20, 1070, y + 70],
                      fill=hex_to_rgb(GREEN),
                      outline=hex_to_rgb(BORDER), width=1)
        # Permanent Delete button (red)
        draw.rectangle([1080, y + 20, 1150, y + 70],
                      fill=hex_to_rgb(RED),
                      outline=hex_to_rgb(BORDER), width=1)

    return img

# Generate all pages
pages = {
    'home': create_home_page,
    'browse': create_browse_page,
    'add': create_add_page,
    'account': create_account_page,
    'price-lookup': create_price_lookup_page,
    'trash': create_trash_page,
}

print("Generating page mockup images for analytics heatmap...")
print(f"Output directory: {output_dir}")
print()

for page_name, create_func in pages.items():
    try:
        img = create_func()
        output_path = os.path.join(output_dir, f'{page_name}.png')
        img.save(output_path, 'PNG')
        file_size = os.path.getsize(output_path) / 1024
        print(f"✅ Created {page_name}.png ({file_size:.1f} KB)")
    except Exception as e:
        print(f"❌ Error creating {page_name}.png: {e}")

print()
print("✅ All page mockups generated!")
print(f"📁 Images saved to: {output_dir}")
print()
print("These images will be used in the analytics heatmap visualization")
print("to show click patterns overlaid on page layouts.")
