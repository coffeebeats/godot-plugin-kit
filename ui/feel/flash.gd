##
## KitFeelFlash describes a flash: what color, how long, and how much of that time is
## spent rising to full before falling away.
##
## The same resource drives the full-screen flash on `KitFeelLayer` and the per-sprite
## flash on `KitFeelHitFlash2D` and `KitFeelHitFlash3D`, so one idea is tuned in one
## place.
##

class_name KitFeelFlash
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## color is the flash color. Its alpha is the peak the flash reaches.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.5)

## duration is the whole flash, in real seconds.
@export var duration: float = 0.08

## rise is the fraction of the duration spent going up. The rest is spent coming down,
## so a small value snaps on and eases off, which is what reads as a hit.
@export_range(0.05, 0.95, 0.05) var rise: float = 0.3
