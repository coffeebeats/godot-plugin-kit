##
## KitFeelImpulse describes one camera disturbance: how hard it hits, how it decays, and
## what it feels like while it lasts.
##
## Character lives here rather than on the layer because a single set of layer-wide
## settings cannot make an explosion feel different from a punch. They differ in noise
## frequency, amplitude and decay, not in magnitude, so an explosion is a slow, wide,
## low-frequency shake and a punch is a short, tight, fast one. With both as resources,
## the same call covers both and tuning them is a data edit made while playtesting.
##
## The noise channel follows Squirrel Eiserloh's trauma model (GDC 2016): trauma
## accumulates, is raised to a power so small hits stay quiet, and decays linearly. The
## directional channel is the impulse half of Cinemachine's split, and is what makes a
## hit read as coming from somewhere rather than as generic rumble.
##

class_name KitFeelImpulse
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Shake")

## trauma is how much shake this impulse adds, from none to the maximum. It accumulates
## and is clamped, so a barrage saturates instead of compounding without limit.
@export_range(0.0, 1.0, 0.05) var trauma: float = 0.5

## decay is how much trauma drains per second.
@export var decay: float = 1.0

## power is the exponent applied to trauma. Above one it keeps small hits nearly
## imperceptible while large ones still reach the cap, which is what reads as impact.
@export_range(1.0, 4.0, 1.0) var power: float = 2.0

## frequency is how many times per second the shake oscillates. Low is a heavy lurch;
## high is a sharp rattle.
@export var frequency: float = 12.0

## amplitude is the largest displacement the shake reaches, in `SubViewport` pixels for
## a 2D map and in metres for a 3D one.
@export var amplitude: Vector2 = Vector2(24.0, 16.0)

## roll is the largest rotation the shake reaches, in radians.
##
## NOTE: Off by default. In 2D it does nothing unless the camera's `ignore_rotation` is
## turned off, and in either dimension it fights a camera controller that writes its own
## rotation.
@export var roll: float = 0.0

@export_group("Kick")

## kick_strength is how far a directional impulse throws the camera, in the same units
## as `amplitude`. It applies only when `impulse` is given a direction.
@export var kick_strength: float = 0.0

## kick_decay is how quickly the kick eases back, as an exponential rate per second.
@export var kick_decay: float = 12.0
