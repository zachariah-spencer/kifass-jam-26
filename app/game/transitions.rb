class Game
  def request_room_transition target_room_id, target_spawn_id, source_exit = nil
    return "The way is lost." unless @rooms[target_room_id]
    return nil if room_transition_active?
    return nil if reset_sequence_active?

    @room_transition = {
      target_room_id: target_room_id,
      target_spawn_id: target_spawn_id,
      source_room_id: @current_room_id,
      source_exit: source_exit,
      started_at: Kernel.tick_count,
      phase: :fade_out
    }
    clear_pointer_gesture
    close_altar
    clear_interaction_text
    nil
  end

  def room_transition_active?
    !!@room_transition
  end

  def request_give_up_reset
    request_reset_sequence(:give_up, true)
  end

  def request_archive_caught_reset
    request_reset_sequence(:archive_entrance, false)
  end

  def request_archive_path_reset
    request_reset_sequence(:archive_entrance, false)
  end

  def request_reset_sequence destination, show_hint
    return if reset_sequence_active?

    close_altar
    clear_interaction_text
    clear_pointer_gesture
    @room_transition = nil
    @player.stop!
    @reset_sequence = {
      destination: destination,
      show_hint: show_hint,
      hint: RESET_HINTS[rand(RESET_HINTS.length)],
      phase: :fade_out,
      started_at: Kernel.tick_count
    }
  end

  def reset_sequence_active?
    !!@reset_sequence
  end

  def update_reset_sequence
    return unless @reset_sequence

    elapsed = reset_sequence_elapsed
    case @reset_sequence[:phase]
    when :fade_out
      if elapsed >= reset_fade_out_frames
        if @reset_sequence[:show_hint]
          set_reset_sequence_phase(:hint_fade_in)
        else
          apply_reset_sequence_destination
          set_reset_sequence_phase(:fade_in)
        end
      end
    when :hint_fade_in
      set_reset_sequence_phase(:hint_hold) if elapsed >= RESET_HINT_FADE_FRAMES
    when :hint_hold
      set_reset_sequence_phase(:hint_fade_out) if elapsed >= RESET_HINT_HOLD_FRAMES
    when :hint_fade_out
      if elapsed >= RESET_HINT_FADE_FRAMES
        apply_reset_sequence_destination
        set_reset_sequence_phase(:fade_in)
      end
    when :fade_in
      @reset_sequence = nil if elapsed >= reset_fade_in_frames
    end
  end

  def set_reset_sequence_phase phase
    @reset_sequence[:phase] = phase
    @reset_sequence[:started_at] = Kernel.tick_count
  end

  def apply_reset_sequence_destination
    reset_sequence = @reset_sequence
    case @reset_sequence[:destination]
    when :give_up
      restart
    when :archive_entrance
      reset_player_to_archive_entrance
    end
    @reset_sequence = reset_sequence
  end

  def reset_sequence_elapsed
    Kernel.tick_count - @reset_sequence[:started_at]
  end

  def reset_fade_out_frames
    @reset_sequence[:show_hint] ? RESET_FADE_OUT_FRAMES : ARCHIVE_PATH_RESET_FADE_FRAMES
  end

  def reset_fade_in_frames
    @reset_sequence[:show_hint] ? RESET_FADE_IN_FRAMES : ARCHIVE_PATH_RESET_FADE_FRAMES
  end

  def update_room_transition
    return unless @room_transition

    elapsed = Kernel.tick_count - @room_transition[:started_at]
    if @room_transition[:phase] == :fade_out && elapsed >= ROOM_FADE_OUT_FRAMES
      enter_room(@room_transition[:target_room_id], @room_transition[:target_spawn_id])
      @room_transition[:phase] = :fade_in
      @room_transition[:started_at] = Kernel.tick_count
    elsif @room_transition[:phase] == :fade_in && elapsed >= ROOM_FADE_IN_FRAMES
      @room_transition = nil
    end
  end

  def enter_room room_id, spawn_id
    clear_archive_off_path_warning
    @current_room_id = room_id
    room = current_room
    @archive_reset_spawn_id = archive_reset_spawn_for(spawn_id) if room_id == :archive
    spawn = room.spawn(spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    reset_archive_enemies if room_id == :archive
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @camera.snap_to(@player)
  end
end
