import cv2
import numpy as np
from shapely.geometry import Polygon, MultiPolygon
from shapely.ops import unary_union
import json
from PIL import Image, ImageTk, ImageDraw
import tkinter as tk

# ---------- Configuration ----------
image_path = "level/Level1.png"
tolerance = 128
simplify_epsilon = 2.0
output_file = "polygons.json"

# ---------- Load image ----------
img = cv2.imread(image_path)
if img is None:
    raise FileNotFoundError(f"Cannot load {image_path}")
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

# ---------- Quantize colors ----------
quantized = np.where(img_rgb >= tolerance, 255, 0).astype(np.uint8)

# ---------- Process each color separately ----------
unique_colors = np.unique(quantized.reshape(-1, 3), axis=0)
result = []

for color in unique_colors:
    mask = cv2.inRange(quantized, color, color)
    if cv2.countNonZero(mask) == 0:
        continue

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    color_polys = []
    for cnt in contours:
        if len(cnt) < 3:
            continue
        cnt = cnt[:, 0, :]
        poly = Polygon(cnt)
        if not poly.is_valid or poly.area < 1:
            continue
        poly = poly.simplify(simplify_epsilon)
        if poly.is_empty:
            continue
        if isinstance(poly, MultiPolygon):
            for p in poly.geoms:
                color_polys.append(np.array(p.exterior.coords).tolist())
        else:
            color_polys.append(np.array(poly.exterior.coords).tolist())

    result.append({
        "color": color.tolist(),
        "polygons": color_polys
    })

with open(output_file, "w") as f:
    json.dump(result, f, indent=2)

print(f"Saved {len(result)} color polygons to {output_file}")

# ---------- GUI to display polygons ----------
root = tk.Tk()
root.title("Polygon Viewer")

# Convert image to PIL
pil_img = Image.fromarray(img_rgb)
draw = ImageDraw.Draw(pil_img)

# Draw polygons
for entry in result:
    color = tuple(entry["color"])
    for poly in entry["polygons"]:
        coords = [tuple(p) for p in poly]
        draw.polygon(coords, outline=color)

# Convert to ImageTk
tk_img = ImageTk.PhotoImage(pil_img)
label = tk.Label(root, image=tk_img)
label.pack()

root.mainloop()
