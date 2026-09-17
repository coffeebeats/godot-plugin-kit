##
## KitFeelHitStop describes a freeze on impact: how long the world stalls and how far
## down time is scaled while it does.
##

class_name KitFeelHitStop
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## duration is how long the freeze lasts, in real seconds. Roughly 50ms reads as a light
## hit and 120ms as a heavy one; much longer stops reading as impact and starts reading
## as a stutter.
@export var duration: float = 0.05

## scale is the time scale held during the freeze. It is deliberately not zero: a hair
## of motion reads as a frozen moment, where a dead stop reads as a dropped frame.
@export_range(0.0, 1.0, 0.01) var scale: float = 0.05
