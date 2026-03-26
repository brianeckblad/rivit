#!/usr/bin/env python3
"""Migrate hard-coded color values in templates to CSS custom properties."""
import re
import os

TEMPLATE_DIR = "app/templates"

# Map of old hex values → new CSS variable references
# Order matters: longer/more specific patterns first
REPLACEMENTS = [
    # Glow shadows → neutral shadows
    (r'box-shadow:\s*0\s+4px\s+16px\s+rgba\(255,\s*229,\s*0,\s*0\.3\)', 'box-shadow: var(--shadow-md)'),
    (r'box-shadow:\s*0\s+6px\s+20px\s+rgba\(255,\s*229,\s*0,\s*0\.4\)', 'box-shadow: var(--shadow-md)'),
    (r'box-shadow:\s*0\s+4px\s+12px\s+rgba\(255,\s*229,\s*0,\s*0\.4\)', 'box-shadow: var(--shadow-md)'),
    (r'box-shadow:\s*0\s+8px\s+32px\s+rgba\(255,\s*229,\s*0,\s*0\.3\)', 'box-shadow: var(--shadow-lg)'),
    (r'box-shadow:\s*0\s+4px\s+12px\s+rgba\(0,\s*0,\s*0,\s*0\.5\)', 'box-shadow: var(--shadow-md)'),
    (r'box-shadow:\s*0\s+4px\s+12px\s+rgba\(0,\s*0,\s*0,\s*0\.3\)', 'box-shadow: var(--shadow-md)'),
    (r'box-shadow:\s*0\s+8px\s+24px\s+rgba\(0,\s*0,\s*0,\s*0\.5\)', 'box-shadow: var(--shadow-lg)'),
    (r'box-shadow:\s*0\s+2px\s+8px\s+rgba\(0,\s*0,\s*0,\s*0\.3\)', 'box-shadow: var(--shadow-sm)'),
    (r'box-shadow:\s*0\s+1px\s+3px\s+rgba\(0,\s*0,\s*0,\s*0\.3\)', 'box-shadow: var(--shadow-sm)'),

    # rgba accent colors
    (r'rgba\(255,\s*229,\s*0,\s*0\.1\)', 'var(--color-accent-subtle)'),
    (r'rgba\(255,\s*229,\s*0,\s*0\.2\)', 'var(--color-accent-subtle)'),
    (r'rgba\(255,\s*229,\s*0,\s*0\.15\)', 'var(--color-accent-subtle)'),
    (r'rgba\(255,\s*229,\s*0,\s*0\.05\)', 'var(--color-accent-subtle)'),

    # rgba danger colors
    (r'rgba\(255,\s*107,\s*107,\s*0\.1\)', 'var(--color-danger-subtle)'),
    (r'rgba\(255,\s*107,\s*107,\s*0\.2\)', 'var(--color-danger-subtle)'),
    (r'rgba\(255,\s*107,\s*107,\s*0\.3\)', 'var(--color-danger-subtle)'),
    (r'rgba\(255,\s*107,\s*107,\s*0\.5\)', 'var(--color-danger-subtle)'),

    # rgba success colors
    (r'rgba\(76,\s*175,\s*80,\s*0\.1\)', 'var(--color-success-subtle)'),
    (r'rgba\(76,\s*175,\s*80,\s*0\.2\)', 'var(--color-success-subtle)'),
    (r'rgba\(76,\s*175,\s*80,\s*0\.3\)', 'var(--color-success-subtle)'),

    # rgba info colors
    (r'rgba\(74,\s*229,\s*255,\s*0\.1\)', 'var(--color-info-subtle)'),
    (r'rgba\(74,\s*229,\s*255,\s*0\.2\)', 'var(--color-info-subtle)'),

    # Gradient replacements (accent)
    (r'linear-gradient\(90deg,\s*#FFE500,\s*#FFD000\)', 'linear-gradient(90deg, var(--color-accent), var(--color-accent-hover))'),
    (r'linear-gradient\(135deg,\s*#FFE500,\s*#F5DB00\)', 'linear-gradient(135deg, var(--color-accent), var(--color-accent-hover))'),

    # Simple hex → token (case-insensitive)
    # Accent
    (r'#FFE500', 'var(--color-accent)'),
    (r'#ffe500', 'var(--color-accent)'),
    (r'#F5DB00', 'var(--color-accent-hover)'),
    (r'#f5db00', 'var(--color-accent-hover)'),
    (r'#FFD000', 'var(--color-accent-hover)'),

    # Backgrounds
    (r'#0A0A0A', 'var(--color-bg)'),
    (r'#0a0a0a', 'var(--color-bg)'),
    (r'#111210', 'var(--color-bg)'),

    # Surface (cards, header, footer)
    (r'#1A1A1A', 'var(--color-surface)'),
    (r'#1a1a1a', 'var(--color-surface)'),

    # Elevated (modals, dropdowns)
    (r'#2A2A2A', 'var(--color-elevated)'),
    (r'#2a2a2a', 'var(--color-elevated)'),
    (r'#333333', 'var(--color-elevated)'),
    (r'#242422', 'var(--color-elevated)'),

    # Borders
    (r'#3A3A3A', 'var(--color-border-hover)'),
    (r'#3a3a3a', 'var(--color-border-hover)'),
    (r'#2E2E2A', 'var(--color-border)'),

    # Text
    (r'#E5E5E5', 'var(--color-text)'),
    (r'#e5e5e5', 'var(--color-text)'),
    (r'#E4E4DE', 'var(--color-text)'),
    (r'#FFFFFF', 'var(--color-text)'),
    (r'#ffffff', 'var(--color-text)'),
    (r'#fff(?=[;\s"\'])', 'var(--color-text)'),

    # Muted text
    (r'#9A9A9A', 'var(--color-text-muted)'),
    (r'#9a9a9a', 'var(--color-text-muted)'),
    (r'#888888', 'var(--color-text-muted)'),
    (r'#999999', 'var(--color-text-muted)'),
    (r'#C4C5BA', 'var(--color-text-muted)'),

    # Dim text
    (r'#666666', 'var(--color-text-dim)'),
    (r'#777777', 'var(--color-text-dim)'),
    (r'#7A7B72', 'var(--color-text-dim)'),

    # Danger
    (r'#ff6b6b', 'var(--color-danger)'),
    (r'#FF6B6B', 'var(--color-danger)'),
    (r'#ff4444', 'var(--color-danger)'),
    (r'#FF4444', 'var(--color-danger)'),
    (r'#ff6666', 'var(--color-danger)'),
    (r'#e74c3c', 'var(--color-danger)'),
    (r'#C45C5C', 'var(--color-danger)'),

    # Success
    (r'#4CAF50', 'var(--color-success)'),
    (r'#4caf50', 'var(--color-success)'),
    (r'#5C8A5C', 'var(--color-success)'),
    (r'#2ecc71', 'var(--color-success)'),
    (r'#45a049', 'var(--color-success)'),

    # Info
    (r'#4AE5FF', 'var(--color-info)'),
    (r'#4ae5ff', 'var(--color-info)'),
    (r'#5C9EB8', 'var(--color-info)'),
    (r'#3498db', 'var(--color-info)'),

    # Warning
    (r'#B8A05C', 'var(--color-warning)'),
    (r'#f39c12', 'var(--color-warning)'),
    (r'#FFA500', 'var(--color-warning)'),
    (r'#ffa500', 'var(--color-warning)'),
    (r'#FF9500', 'var(--color-warning)'),
    (r'#FFD700', 'var(--color-warning)'),
    (r'#ffc107', 'var(--color-warning)'),
    (r'#ff9800', 'var(--color-warning)'),

    # Additional danger variants
    (r'#ef4444', 'var(--color-danger)'),
    (r'#EF4444', 'var(--color-danger)'),
    (r'#dc2626', 'var(--color-danger-hover)'),
    (r'#FF4A4A', 'var(--color-danger)'),
    (r'#FF4757', 'var(--color-danger)'),
    (r'#ff8888', 'var(--color-danger)'),
    (r'#FF4A6E', 'var(--color-danger)'),

    # Additional success variants
    (r'#34d399', 'var(--color-success)'),
    (r'#22c55e', 'var(--color-success)'),
    (r'#4AE54B', 'var(--color-success)'),

    # Additional info variants
    (r'#3b82f6', 'var(--color-info)'),
    (r'#4F46E5', 'var(--color-info)'),
    (r'#4facfe', 'var(--color-info)'),
    (r'#5AF5FF', 'var(--color-info)'),

    # Short hex — text
    (r'#FFF(?=[;\s"\',\)])', 'var(--color-text)'),
    (r'#AAA(?=[;\s"\',\)])', 'var(--color-text-muted)'),
    (r'#CCC(?=[;\s"\',\)])', 'var(--color-text-muted)'),

    # Short hex — dim text
    (r'#666(?=[;\s"\',\)])', 'var(--color-text-dim)'),
    (r'#555(?=[;\s"\',\)])', 'var(--color-text-dim)'),
    (r'#000(?=[;\s"\',\)])', '#000'),  # leave black as-is (used for outlines)

    # Additional muted / dim text
    (r'#6B6B6B', 'var(--color-text-dim)'),
    (r'#6A6A6A', 'var(--color-text-dim)'),
    (r'#5A5A5A', 'var(--color-text-dim)'),
    (r'#4A4A4A', 'var(--color-text-dim)'),

    # Additional background tones
    (r'#1E1E1E', 'var(--color-surface)'),

    # Additional accent-ish
    (r'#FFF066', 'var(--color-accent)'),
    (r'#4FF3AE', 'var(--color-success)'),

    # Dark accent backgrounds
    (r'#1A1500', 'var(--color-accent-subtle)'),
    (r'#4d3300', 'var(--color-warning-subtle)'),
    (r'#1a4d1a', 'var(--color-success-subtle)'),
]

# Files to skip (already migrated or not applicable)
SKIP_FILES = set()

def migrate_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content
    changes = 0

    for pattern, replacement in REPLACEMENTS:
        new_content = re.sub(pattern, replacement, content)
        if new_content != content:
            count = len(re.findall(pattern, content))
            changes += count
            content = new_content

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        return changes
    return 0


def main():
    total_changes = 0
    for filename in sorted(os.listdir(TEMPLATE_DIR)):
        if not filename.endswith('.html'):
            continue
        if filename in SKIP_FILES:
            continue
        filepath = os.path.join(TEMPLATE_DIR, filename)
        changes = migrate_file(filepath)
        if changes:
            print(f"  {filename}: {changes} replacements")
            total_changes += changes
        else:
            print(f"  {filename}: no changes")

    print(f"\nTotal: {total_changes} replacements across all templates")


if __name__ == '__main__':
    main()

