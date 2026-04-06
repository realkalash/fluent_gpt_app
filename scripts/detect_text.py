"""Text detection using comic-text-detector. Called from FluentGPT.

Dependencies are installed into a venv by the app automatically.
For standalone use: pip install comic-text-detector numpy Pillow
"""
import sys
import json


def detect(image_path):
    from comic_text_detector.inference import TextDetector
    import numpy as np
    from PIL import Image

    model = TextDetector(detect_model="ctd")
    img = np.array(Image.open(image_path).convert("RGB"))
    text_lines, raw_results = model(img)
    regions = []
    for line in text_lines:
        pts = np.array(line)
        x, y = float(pts[:, 0].min()), float(pts[:, 1].min())
        w = float(pts[:, 0].max()) - x
        h = float(pts[:, 1].max()) - y
        regions.append({
            "x": x,
            "y": y,
            "w": w,
            "h": h,
            "confidence": 1.0,
        })
    print(json.dumps(regions))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        detect(sys.argv[1])
    else:
        print("[]")
