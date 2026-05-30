class Game
  def update_enemy args
    return false unless @current_room_id == :archive
    return false unless @enemy.room_id == @current_room_id

    @enemy.update(args, @player, current_room, enemy_patrol_points(current_room), word_sacrificed?("BELL"))

    if @enemy.room_id == @current_room_id && rects_intersect?(@enemy.rect, @player.rect)
      request_archive_caught_reset
      return true
    end

    false
  end

  def exits
    interactables.find_all { |interactable| interactable.is_a?(Exit) }
  end

  def traversable_exits
    exits.find_all { |exit| exit.can_traverse? }
  end

  def active_barriers
    barriers = current_room.barriers.dup
    barriers << HALL_BELL_GATE if current_room.id == :hall && !knows_word?("KEY")
    barriers << SANCTUM_KEY_GATE if current_room.id == :sanctum && !knows_word?("KEY")
    barriers
  end

  def knows_word? word
    @learned_words.include?(word)
  end

  def word_sacrificed? word
    @sacrificed_words.include?(word)
  end

  def start_key_gate_animation direction
    update_key_gate_frame
    @key_gate_animation_started_at = Kernel.tick_count
    @key_gate_animation_direction = direction
    @key_gate_animation_from_frame = @key_gate_frame
  end

  def update_key_gate_frame
    return unless @key_gate_animation_started_at && @key_gate_animation_direction

    elapsed_frames = (Kernel.tick_count - @key_gate_animation_started_at).idiv(LOCKED_GATE_FRAME_HOLD)
    if @key_gate_animation_direction == :open
      @key_gate_frame = (@key_gate_animation_from_frame + elapsed_frames).clamp(0, LOCKED_GATE_FRAME_COUNT - 1)
    else
      @key_gate_frame = (@key_gate_animation_from_frame - elapsed_frames).clamp(0, LOCKED_GATE_FRAME_COUNT - 1)
    end

    target_frame = @key_gate_animation_direction == :open ? LOCKED_GATE_FRAME_COUNT - 1 : 0
    return unless @key_gate_frame == target_frame

    @key_gate_animation_started_at = nil
    @key_gate_animation_direction = nil
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
    @enemy.stun!(BELL_STUN_FRAMES)
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
    {
      x: WORLD_W / 2 - NamelessThing::SIZE / 2,
      y: WORLD_H / 2 - NamelessThing::SIZE / 2
    }
  end

  def archive_reset_spawn_for spawn_id
    spawn_id == :from_sanctum ? :from_sanctum : :from_hall
  end

  def archive_safe_paths
    raw_paths = [
      { x: G[5], y: G[33], w: G[19], h: G[17] },
      { x: G[14], y: G[38], w: G[15], h: G[7] },
      { x: G[29], y: G[38], w: G[6], h: G[21] },
      { x: G[29], y: G[53], w: G[23], h: G[7] },
      { x: G[49], y: G[33], w: G[6], h: G[27] },
      { x: G[49], y: G[33], w: G[20], h: G[7] },
      { x: G[66], y: G[21], w: G[6], h: G[19] },
      { x: G[66], y: G[21], w: G[20], h: G[7] },
      { x: G[82], y: G[21], w: G[6], h: G[21] },
      { x: G[82], y: G[36], w: G[23], h: G[7] },
      { x: G[100], y: G[36], w: G[25], h: G[8] },
      { x: G[54], y: G[53], w: G[6], h: G[15] },
      { x: G[54], y: G[62], w: G[22], h: G[7] }
    ]

    raw_paths
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
    @enemy.reset!(:archive, archive_enemy_spawn)
    @camera.snap_to(@player)
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
