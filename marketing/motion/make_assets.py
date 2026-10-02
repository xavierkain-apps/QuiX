"""Two textures for the motion piece: the photo collage that fills the opening headline, and a
film-grain tile. Both are derived from the project's own session stills.   python3 make_assets.py"""
import pathlib, numpy as np
from PIL import Image, ImageEnhance

HERE = pathlib.Path(__file__).resolve().parent
THUMBS = HERE.parent.parent / "site" / "assets" / "thumbs"
OUT = HERE / "assets"; OUT.mkdir(exist_ok=True)

names = ["h1","k-jump","h2","wing","h4","k-sea","h7","para","h9","k-beach","h5","h10","flare","h3","k-water","h11","h6","h8"]
w, h, cols, rows = 400, 225, 8, 4
col = Image.new("RGB", (w * cols, h * rows))
for i in range(cols * rows):
    im = Image.open(THUMBS / f"{names[i % len(names)]}.jpg").convert("RGB").resize((w, h), Image.LANCZOS)
    col.paste(im, ((i % cols) * w, (i // cols) * h))
col = ImageEnhance.Contrast(ImageEnhance.Color(col).enhance(1.25)).enhance(1.1)
col = ImageEnhance.Brightness(col).enhance(1.15)
col.save(OUT / "collage.jpg", quality=88)

rng = np.random.default_rng(3)
g = np.clip(128 + rng.normal(0, 46, (256, 256)), 0, 255).astype(np.uint8)
Image.fromarray(g, "L").save(OUT / "grain.png")
print("collage.jpg", col.size, "grain.png (256, 256)")
