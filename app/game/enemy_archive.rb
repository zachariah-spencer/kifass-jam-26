class Game
  def update_enemy args
    return false if ending_sequence_triggered?

    current_enemies.each do |enemy|
      enemy.update(
        args,
        @player,
        current_room,
        enemy_patrol_points(current_room),
        monster_speed_multiplier
      )

      next unless rects_intersect?(enemy.rect, @player.rect)

      if @current_room_id == :archive
        request_archive_caught_reset
      else
        request_give_up_reset
      end
      return true
    end

    false
  end

  def current_enemies
    @enemies.find_all { |enemy| enemy.room_id == @current_room_id }
  end

  def exits
    interactables.find_all { |interactable| interactable.is_a?(Exit) }
  end

  def traversable_exits
    exits.find_all { |exit| exit.can_traverse? }
  end

  def active_barriers
    barriers = current_room.barriers.dup
    current_room.locked_gates.each do |gate|
      barriers << gate[:rect] if key_gate_closed?(gate[:id])
    end
    barriers
  end

  def knows_word? word
    @learned_words.include?(word)
  end

  def word_sacrificed? word
    @sacrificed_words.include?(word)
  end

  def key_gate_closed? gate_id
    !key_shortcuts_open?
  end

  def key_shortcuts_open?
    knows_word?("KEY") && !word_sacrificed?("KEY")
  end

  def reset_key_gate_states
    @key_gate_states = {}
    @rooms.each_value do |room|
      room.locked_gates.each do |gate|
        @key_gate_states[gate[:id]] ||= new_key_gate_state(0)
      end
    end
  end

  def new_key_gate_state frame
    {
      frame: frame,
      animation_started_at: nil,
      animation_direction: nil,
      animation_from_frame: frame
    }
  end

  def start_key_gate_animation direction
    @key_gate_states.each_key { |gate_id| start_key_gate_animation_for(gate_id, direction) }
  end

  def start_key_gate_animation_for gate_id, direction
    update_key_gate_frame(gate_id)
    state = @key_gate_states[gate_id]
    state[:animation_started_at] = Kernel.tick_count
    state[:animation_direction] = direction
    state[:animation_from_frame] = state[:frame]
  end

  def update_key_gate_frame gate_id
    state = @key_gate_states[gate_id]
    return state[:frame] unless state
    return state[:frame] unless state[:animation_started_at] && state[:animation_direction]

    elapsed_frames = (Kernel.tick_count - state[:animation_started_at]).idiv(LOCKED_GATE_FRAME_HOLD)
    if state[:animation_direction] == :open
      state[:frame] = (state[:animation_from_frame] + elapsed_frames).clamp(0, LOCKED_GATE_FRAME_COUNT - 1)
    else
      state[:frame] = (state[:animation_from_frame] - elapsed_frames).clamp(0, LOCKED_GATE_FRAME_COUNT - 1)
    end

    target_frame = state[:animation_direction] == :open ? LOCKED_GATE_FRAME_COUNT - 1 : 0
    return state[:frame] unless state[:frame] == target_frame

    state[:animation_started_at] = nil
    state[:animation_direction] = nil
    state[:frame]
  end

  def ending_sequence_triggered?
    @ending_sequence_triggered
  end

  def input_locked?
    ending_sequence_triggered? || reset_sequence_active?
  end

  def ending_complete?
    @ending_phase == :done
  end

  def bell_input? args, click
    return false unless knows_word?("BELL")
    return false if word_sacrificed?("BELL")

    args.inputs.keyboard.key_down.e || !!click
  end

  def ring_bell
    if bell_on_cooldown?
      @bell_failed_pulse_until = Kernel.tick_count + BELL_FAILED_PULSE_FRAMES
      return
    end

    @bell_last_used_at = Kernel.tick_count
    current_enemies.each { |enemy| enemy.stun!(BELL_STUN_FRAMES) }
  end

  def bell_on_cooldown?
    return false unless @bell_last_used_at

    Kernel.tick_count - @bell_last_used_at < BELL_COOLDOWN_FRAMES
  end

  def bell_cooldown_progress
    return 0 unless @bell_last_used_at

    elapsed = Kernel.tick_count - @bell_last_used_at
    return 0 if elapsed >= BELL_COOLDOWN_FRAMES

    1.0 - elapsed.to_f / BELL_COOLDOWN_FRAMES
  end

  def nearby_interactables
    interactables.find_all { |interactable| nearby_interactable?(interactable) }
  end

  def nearby_interactable? interactable
    distance_between(@player.center, interactable.center) <= INTERACTION_RADIUS
  end

  def enemy_patrol_points room
    return archive_enemy_patrol_points if room.id == :archive

    room_exits = traversable_exits
    return [{ x: room.play_area[:x] + room.play_area[:w] / 2, y: room.play_area[:y] + room.play_area[:h] / 2 }] if room_exits.empty?

    room_exits.map do |exit|
      {
        x: (exit.center[:x] + room.world_w / 2) / 2,
        y: exit.center[:y]
      }
    end
  end

  def archive_enemy_patrol_points
    [
      { x: WORLD_W / 2, y: G[56] },
      { x: G[114], y: WORLD_H / 2 },
      { x: WORLD_W / 2, y: G[28] },
      { x: G[16], y: WORLD_H / 2 }
    ]
  end

  def archive_enemy_spawn
    enemy_spawn("archive_primary")
  end

  def archive_second_enemy_spawn
    enemy_spawn("archive_bell_sacrifice")
  end

  def sanctum_enemy_spawn
    enemy_spawn("sanctum_key_sacrifice")
  end

  def ensure_bell_sacrifice_enemy!
    return if @enemies.any? { |enemy| enemy.room_id == :archive && enemy.id == :archive_bell_sacrifice }

    spawn = archive_second_enemy_spawn
    @enemies << NamelessThing.new(:archive, spawn[:x], spawn[:y], :archive_bell_sacrifice)
  end

  def ensure_sanctum_enemy!
    return unless word_sacrificed?("KEY")
    return if @enemies.any? { |enemy| enemy.room_id == :sanctum }

    spawn = sanctum_enemy_spawn
    @enemies << NamelessThing.new(:sanctum, spawn[:x], spawn[:y], :sanctum_key_sacrifice)
  end

  def monster_speed_multiplier
    word_sacrificed?("BELL") ? BELL_SACRIFICE_SPEED_MULTIPLIER : 1.0
  end

  def archive_reset_spawn_for spawn_id
    spawn_id == :from_sanctum ? :from_sanctum : :from_hall
  end

  def archive_safe_paths
    room = @rooms[:archive]
    room ? room.safe_paths : []
  end

  def expanded_archive_safe_path path
    {
      x: path[:x] - ARCHIVE_SAFE_PATH_EXTRA_WIDTH / 2,
      y: path[:y] - ARCHIVE_SAFE_PATH_EXTRA_WIDTH / 2,
      w: path[:w] + ARCHIVE_SAFE_PATH_EXTRA_WIDTH,
      h: path[:h] + ARCHIVE_SAFE_PATH_EXTRA_WIDTH
    }
  end

  def reset_player_if_off_archive_path
    return false unless @current_room_id == :archive
    return false if point_on_archive_safe_path?(@player.center)

    request_archive_path_reset
    true
  end

  def reset_player_to_archive_entrance
    spawn = current_room.spawn(@archive_reset_spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.stop!
    close_altar
    clear_interaction_text
    reset_archive_enemies
    @camera.snap_to(@player)
  end

  def reset_archive_enemies
    @enemies.each do |enemy|
      next unless enemy.room_id == :archive

      spawn = enemy.id == :archive_bell_sacrifice ? archive_second_enemy_spawn : archive_enemy_spawn
      enemy.reset!(:archive, spawn)
    end
  end

  def point_on_archive_safe_path? point
    archive_safe_paths.any? do |path|
      point_inside_rect?(
        point,
        {
          x: path[:x] - ARCHIVE_SAFE_PATH_TOLERANCE,
          y: path[:y] - ARCHIVE_SAFE_PATH_TOLERANCE,
          w: path[:w] + ARCHIVE_SAFE_PATH_TOLERANCE * 2,
          h: path[:h] + ARCHIVE_SAFE_PATH_TOLERANCE * 2
        }
      )
    end
  end

end
