# Slices assets/placeholder/source/character_sheet.webp (5 columns x 3 rows) into one transparent PNG
# per labelled cell, named by the sheet's labels (see ../README.md). Not part of the game or its tests.
# Background is removed by flood fill from each cell's border, so grey areas inside a sprite (enclosed
# by its outline) stay opaque. Usage: python3 -I slice_sheet.py <sheet> <out_dir>
import sys
from collections import deque
import numpy as np
from PIL import Image

NAMES = [["tom", "goblin_pledge", "goblin_bouncer", "keg_slime", "dorm_rats"],
         ["skeleton_intern", "boo_zer", "mimic_cooler", "kobold_ra", "goblin_shot_caller"],
         ["hall_monitor_golem", "sewer_gator", "goblin_king_chad", "rat_king", None]]
BG = np.array([89, 90, 99], dtype=np.int32)   # the sheet's background colour
LOW, HIGH = 12, 36                            # colour distance: <= LOW fully clear, >= HIGH opaque (edge ramp between)
MIN_PART = 400                                # pixels; smaller opaque parts (the id labels) are cleared
PAD = 4                                       # transparent margin around each cut-out, in pixels


def components(mask):
	"""Yields lists of (y, x) for each 4-connected True region of mask."""
	seen = np.zeros_like(mask)
	h, w = mask.shape
	for sy in range(h):
		for sx in range(w):
			if not mask[sy, sx] or seen[sy, sx]:
				continue
			part, q = [], deque([(sy, sx)])
			seen[sy, sx] = True
			while q:
				y, x = q.popleft()
				part.append((y, x))
				for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
					if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
						seen[ny, nx] = True
						q.append((ny, nx))
			yield part


sheet = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.int32)
h, w, _ = sheet.shape
dist = np.abs(sheet - BG).max(axis=2)
for r, row in enumerate(NAMES):
	for c, name in enumerate(row):
		if name is None:
			continue
		y0, y1 = round(r * h / 3), round((r + 1) * h / 3)
		x0, x1 = round(c * w / 5), round((c + 1) * w / 5)
		d = dist[y0:y1, x0:x1]
		ch, cw = d.shape
		# outside: background-like pixels reachable from the cell border.
		bgish = d < HIGH
		outside = np.zeros_like(bgish)
		q = deque((y, x) for y in range(ch) for x in (0, cw - 1) if bgish[y, x])
		q.extend((y, x) for x in range(cw) for y in (0, ch - 1) if bgish[y, x])
		for y, x in q:
			outside[y, x] = True
		while q:
			y, x = q.popleft()
			for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
				if 0 <= ny < ch and 0 <= nx < cw and bgish[ny, nx] and not outside[ny, nx]:
					outside[ny, nx] = True
					q.append((ny, nx))
		alpha = np.full(d.shape, 255, dtype=np.int32)
		alpha[outside] = np.clip((d[outside] - LOW) * 255 // (HIGH - LOW), 0, 255)
		opaque = alpha > 0
		keep = np.zeros_like(opaque)
		for part in components(opaque):
			if len(part) >= MIN_PART:
				ys, xs = zip(*part)
				keep[list(ys), list(xs)] = True
		alpha[~keep] = 0
		ys, xs = np.nonzero(keep)
		top, bottom = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, ch)
		left, right = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, cw)
		rgba = np.dstack([sheet[y0:y1, x0:x1], alpha]).astype(np.uint8)[top:bottom, left:right]
		Image.fromarray(rgba, "RGBA").save(f"{sys.argv[2]}/{name}.png", optimize=True)
		print(name, rgba.shape[1], "x", rgba.shape[0])
