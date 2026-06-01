class Game
  def update args
    return if handle_level_editor_toggle(args)
    return update_level_editor(args) if level_editor_active?

    return update_ending_sequence(args) if ending_sequence_triggered?
    return update_reset_sequence if reset_sequence_active?

    update_room_transition(args)
    return if room_transition_active?

    update_pointer_gesture(args)
    handle_debug_input(args)
    handle_interaction(args)
    update_interaction_text(args)
    interactables.each { |interactable| interactable.update(args) }
    @player.update(args, nil, active_barriers, pointer_movement_vector)
    update_player_footsteps(args, @player.moving?)
    close_altar_if_player_left_range
    return if reset_player_if_off_archive_path

    return if update_enemy(args)

    @camera.follow(@player)
    handle_exit_transition
  end

  def update_player_footsteps args, walking
    return unless walking
    return if @last_footstep_at && Kernel.tick_count - @last_footstep_at < FOOTSTEP_INTERVAL_FRAMES

    @last_footstep_at = Kernel.tick_count
    @footstep_audio_index += 1
    pitch = FOOTSTEP_PITCH_MIN + rand * (FOOTSTEP_PITCH_MAX - FOOTSTEP_PITCH_MIN)
    args.audio[:"footstep_#{@footstep_audio_index}"] = {
      input: FOOTSTEP_SOUND_PATH,
      gain: FOOTSTEP_GAIN.to_f,
      pitch: pitch,
      looping: false
    }
  end

  def play_typing_sound args
    @typing_audio_index += 1
    pitch = TYPING_PITCH_MIN + rand * (TYPING_PITCH_MAX - TYPING_PITCH_MIN)
    args.audio[:"typing_#{@typing_audio_index}"] = {
      input: TYPING_SOUND_PATH,
      gain: TYPING_GAIN.to_f,
      pitch: pitch,
      looping: false
    }
  end

  def play_scramble_sound args
    @scramble_audio_index += 1
    args.audio[:"scramble_#{@scramble_audio_index}"] = {
      input: SCRAMBLE_SOUND_PATH,
      gain: SCRAMBLE_GAIN.to_f,
      looping: false
    }
  end

  def play_altar_crashing_sound args
    @altar_crashing_audio_index += 1
    args.audio[:"altar_crashing_#{@altar_crashing_audio_index}"] = {
      input: ALTAR_CRASHING_SOUND_PATH,
      gain: ALTAR_CRASHING_GAIN.to_f,
      looping: false
    }
  end

  def play_nameless_sound args, high_pitch: word_sacrificed?("BELL"), input: nil
    @nameless_audio_index += 1
    args.audio[:"nameless_#{@nameless_audio_index}"] = {
      input: input || NAMELESS_SOUND_PATHS[rand(NAMELESS_SOUND_PATHS.length)],
      gain: NAMELESS_GAIN.to_f,
      pitch: nameless_pitch(high_pitch),
      looping: false
    }
  end

  def nameless_pitch high_pitch
    base_pitch = high_pitch ? NAMELESS_SACRIFICED_BELL_PITCH : NAMELESS_PITCH
    base_pitch + rand * NAMELESS_PITCH_SPREAD - NAMELESS_PITCH_SPREAD / 2.0
  end

  def handle_interaction args
    taps = pointer_taps
    tap = taps.first
    return handle_altar_selection(args, tap) if @altar_open && tap
    return if @altar_open

    taps.each do |candidate_tap|
      world_click = @camera.world_point(candidate_tap)
      interactable = nearby_interactables.find { |candidate| candidate.contains_point?(world_click) }
      if interactable
        set_interaction_text(interactable.interact(self))
        return
      end
    end

    bell_input = bell_input?(args, tap)
    ring_bell if bell_input
    set_interaction_text(nil) if tap && !bell_input
  end

  def update_pointer_gesture args
    @pointer_taps = []
    @pointer_drag_vector = nil

    if touch_input_active?(args)
      @pointer_gesture = nil
      update_touch_gestures(args)
      @pointer_tap = @pointer_taps.first
      return
    end

    update_mouse_gesture(args)
    @pointer_tap = @pointer_taps.first
  end

  def update_mouse_gesture args
    if args.inputs.mouse.down
      @pointer_gesture = {
        start: point_hash(args.inputs.mouse.down),
        current: point_hash(args.inputs.mouse.down),
        started_at: Kernel.tick_count,
        dragged: false
      }
    end

    return unless @pointer_gesture

    if args.inputs.mouse.held
      @pointer_gesture[:current] = point_hash(args.inputs.mouse)
      update_pointer_drag_state
      @pointer_drag_vector = pointer_drag_vector if @pointer_gesture[:dragged]
    end

    return unless args.inputs.mouse.up

    @pointer_gesture[:current] = point_hash(args.inputs.mouse.up)
    update_pointer_drag_state
    @pointer_taps << @pointer_gesture[:current] if pointer_tap?
    @pointer_gesture = nil
    @pointer_drag_vector = nil
  end

  def update_touch_gestures args
    touches = args.inputs.touch || {}

    touches.each do |touch_id, touch|
      @touch_gestures[touch_id] ||= {
        start: point_hash(touch),
        current: point_hash(touch),
        started_at: Kernel.tick_count,
        dragged: false
      }

      gesture = @touch_gestures[touch_id]
      gesture[:current] = point_hash(touch)
      update_touch_drag_state(touch_id, gesture)
    end

    ended_touch_ids = @touch_gestures.keys - touches.keys
    ended_touch_ids.each do |touch_id|
      gesture = @touch_gestures[touch_id]
      @pointer_taps << gesture[:current] if touch_tap?(gesture)
      @touch_gestures.delete(touch_id)
      @touch_movement_id = nil if @touch_movement_id == touch_id
    end

    movement_gesture = @touch_gestures[@touch_movement_id]
    @pointer_drag_vector = gesture_vector(movement_gesture) if movement_gesture
  end

  def update_touch_drag_state touch_id, gesture
    return unless gesture_distance_squared(gesture) >= POINTER_DRAG_DEADZONE * POINTER_DRAG_DEADZONE

    gesture[:dragged] = true
    @touch_movement_id ||= touch_id
  end

  def update_pointer_drag_state
    return unless gesture_distance_squared(@pointer_gesture) >= POINTER_DRAG_DEADZONE * POINTER_DRAG_DEADZONE

    @pointer_gesture[:dragged] = true
  end

  def pointer_tap?
    !@pointer_gesture[:dragged] &&
      Kernel.tick_count - @pointer_gesture[:started_at] <= POINTER_TAP_MAX_FRAMES
  end

  def touch_tap? gesture
    !gesture[:dragged] &&
      Kernel.tick_count - gesture[:started_at] <= POINTER_TAP_MAX_FRAMES
  end

  def pointer_movement_vector
    return nil if @altar_open

    @pointer_drag_vector
  end

  def pointer_drag_vector
    gesture_vector(@pointer_gesture)
  end

  def gesture_vector gesture
    return nil unless gesture

    dx = gesture[:current][:x] - gesture[:start][:x]
    dy = gesture[:current][:y] - gesture[:start][:y]
    length = Math.sqrt(dx * dx + dy * dy)
    return nil if length == 0

    { x: dx / length, y: dy / length }
  end

  def gesture_distance_squared gesture
    dx = gesture[:current][:x] - gesture[:start][:x]
    dy = gesture[:current][:y] - gesture[:start][:y]
    dx * dx + dy * dy
  end

  def touch_input_active? args
    touch_platform? && ((args.inputs.touch && args.inputs.touch.length > 0) || @touch_gestures.length > 0)
  end

  def touch_platform?
    DR.platform?(:touch)
  end

  def pointer_taps
    @pointer_taps || []
  end

  def point_hash point
    return { x: point[:x], y: point[:y] } if point.is_a?(Hash)

    { x: point.x, y: point.y }
  end

  def clear_pointer_gesture
    @pointer_gesture = nil
    @touch_gestures = {}
    @touch_movement_id = nil
    @pointer_taps = []
    @pointer_tap = nil
    @pointer_drag_vector = nil
  end

  def handle_debug_input args
    grant_key_object if args.inputs.keyboard.key_down.y
  end

  def grant_key_object
    return set_interaction_text("The key has already been sacrificed.") if word_sacrificed?("KEY")

    unless @learned_words.include?("KEY")
      @learned_words << "KEY"
      start_key_gate_animation(:open)
    end
    @learned_object_ids << :archive_key unless @learned_object_ids.include?(:archive_key)
    @learned_word_sources["KEY"] = :archive_key
    set_interaction_text("Debug: you remember that this is a KEY.")
  end

end
