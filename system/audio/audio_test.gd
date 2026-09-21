##
## Unit tests for `SystemAudio`, on the scene kit ships.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const AudioScene := preload("audio.tscn")

# -- TEST METHODS -------------------------------------------------------------------- #


func test_audio_ready_loads_module() -> void:
	# Given: The audio scene.
	var audio := AudioScene.instantiate()

	# When: It enters the scene tree.
	add_child_autofree(audio)

	# Then: Its module loaded.
	assert_true(KitModules.is_loaded(&"audio"))


func test_audio_ready_places_sound_player_for_std() -> void:
	# Given: The audio scene in the scene tree.
	var audio := AudioScene.instantiate()
	add_child_autofree(audio)

	# When: std looks up the game's sound player.
	var player = StdGroup.get_sole_member(StdSoundEventPlayer.GROUP_SOUND_PLAYER)

	# Then: It finds the audio system's own player.
	assert_same(player, audio.sound_player)


func test_audio_play_plays_through_sound_player() -> void:
	# Given: The audio scene in the scene tree.
	var audio := AudioScene.instantiate()
	add_child_autofree(audio)

	# Given: A sound event.
	var event := _create_event()

	# When: The event is played.
	var instance: StdSoundInstance = audio.play(event)

	# Then: It is playing.
	assert_not_null(instance)
	assert_false(instance.is_done())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_event() -> StdSoundEvent1D:
	var event := StdSoundEvent1D.new()

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 1.0
	event.stream = stream

	var bus := StdAudioBusStatic.new()
	bus.name = &"Master"
	event.bus = bus

	return event
