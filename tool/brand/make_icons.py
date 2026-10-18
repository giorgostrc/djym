"""Cuts the djinn out of djym-icon.jpg and writes the Android launcher icons
(adaptive foreground, themed monochrome, legacy) and the in-app logo.

Run from the repo root:
  python3 tool/brand/make_icons.py tool/brand/djym-icon.jpg android/app/src/main/res assets/brand
"""
import os, sys
from PIL import Image, ImageFilter

src, res_dir, asset_dir = sys.argv[1], sys.argv[2], sys.argv[3]
original = Image.open(src).convert('RGB')
width, height = original.size
corner = [original.getpixel((x, y)) for x in range(40) for y in range(40)]
background = tuple(sorted(channel)[len(channel) // 2] for channel in zip(*corner))

rgba = []
for r, g, b in original.get_flattened_data():
    distance = ((r - background[0]) ** 2 + (g - background[1]) ** 2 + (b - background[2]) ** 2) ** 0.5
    alpha = min(max((distance - 22) / (70 - 22), 0), 1)
    if alpha == 0:
        rgba.append((0, 0, 0, 0))
        continue
    colour = [min(max(round((c - (1 - alpha) * bc) / alpha), 0), 255) for c, bc in zip((r, g, b), background)]
    rgba.append((*colour, round(alpha * 255)))
foreground = Image.new('RGBA', original.size)
foreground.putdata(rgba)
foreground = foreground.crop(foreground.getbbox())
print('background', background, 'art', foreground.size)

def fit(image, box):
    scale = box / max(image.size)
    return image.resize((round(image.size[0] * scale), round(image.size[1] * scale)), Image.LANCZOS)

def centred(image, size, art_fraction):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    art = fit(image, size * art_fraction)
    canvas.paste(art, ((size - art.size[0]) // 2, (size - art.size[1]) // 2), art)
    return canvas

monochrome_source = Image.new('RGBA', foreground.size, (255, 255, 255, 0))
monochrome_source.putalpha(foreground.getchannel('A'))

densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, factor in densities.items():
    folder = os.path.join(res_dir, f'mipmap-{name}')
    os.makedirs(folder, exist_ok=True)
    adaptive = round(108 * factor)
    # The safe zone is a 66 dp circle; the art's diagonal stays inside it.
    centred(foreground, adaptive, 0.58).save(os.path.join(folder, 'ic_launcher_foreground.png'))
    centred(monochrome_source, adaptive, 0.58).save(os.path.join(folder, 'ic_launcher_monochrome.png'))
    legacy = Image.new('RGBA', (round(48 * factor),) * 2, tuple(int(c) for c in (0x1a, 0x53, 0x5c)) + (255,))
    art = fit(foreground, legacy.size[0] * 0.78)
    legacy.paste(art, ((legacy.size[0] - art.size[0]) // 2, (legacy.size[1] - art.size[1]) // 2), art)
    legacy.save(os.path.join(folder, 'ic_launcher.png'))

for scale, suffix in [(1, ''), (2, '2.0x/'), (3, '3.0x/')]:
    os.makedirs(os.path.join(asset_dir, suffix), exist_ok=True)
    fit(foreground, 40 * scale).save(os.path.join(asset_dir, suffix, 'djinn.png'))
