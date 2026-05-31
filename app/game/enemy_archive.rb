class Game
  ENEMY_RANDOM_SPAWN_ATTEMPTS = 80
  ENEMY_PLAYER_SPAWN_BUFFER = S.value(384)
  SANCTUM_LEFT_MAZE_SPAWN_AREA = { x: G[22], y: G[4], w: G[40], h: G[74] }
  SANCTUM_ENEMY_SPEED_MULTIPLIER = 0.75

  def update_enemy args
    return false if ending_sequence_triggered?

    current_enemies.each do |enemy|
      enemy.update(
        args,
        @player,
        current_room,
        enemy_patrol_points(current_room),
        enemy_speed_multiplier(enemy)
      )

      next unless rects_intersect?(enemy.rect, @player.rect)

      if @current_room_id == :archive
        request_archive_caught_reset
      elsif @current_room_id == :sanctum
        request_sanctum_caught_reset
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

  def enemy_speed_multiplier enemy
    multiplier = monster_speed_multiplier
    multiplier *= SANCTUM_ENEMY_SPEED_MULTIPLIER if enemy.room_id == :sanctum
    multiplier
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

  def archive_enemy_spawn extra_blockers = []
    randomized_enemy_spawn("archive_primary", extra_blockers)
  end

  def archive_second_enemy_spawn extra_blockers = []
    randomized_enemy_spawn("archive_bell_sacrifice", extra_blockers)
  end

  def sanctum_enemy_spawn extra_blockers = []
    randomized_enemy_spawn("sanctum_key_sacrifice", extra_blockers)
  end

  def ensure_bell_sacrifice_enemy!
    return if @enemies.any? { |enemy| enemy.room_id == :archive && enemy.id == :archive_bell_sacrifice }

    spawn = archive_second_enemy_spawn(enemy_rects_for_room(:archive))
    @enemies << NamelessThing.new(:archive, spawn[:x], spawn[:y], :archive_bell_sacrifice)
  end

  def ensure_sanctum_enemy!
    return unless word_sacrificed?("KEY")
    return if @enemies.any? { |enemy| enemy.room_id == :sanctum }

    spawn = sanctum_enemy_spawn(enemy_rects_for_room(:sanctum))
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

  def randomized_enemy_spawn id, extra_blockers = []
    case id
    when "archive_primary", "archive_bell_sacrifice"
      random_archive_enemy_spawn(extra_blockers) || enemy_spawn(id)
    when "sanctum_key_sacrifice"
      random_sanctum_enemy_spawn(extra_blockers) || enemy_spawn(id)
    else
      enemy_spawn(id)
    end
  end

  def random_archive_enemy_spawn extra_blockers = []
    room = @rooms[:archive]
    paths = archive_safe_paths.find_all { |path| rect_can_fit_enemy?(path) }
    return nil unless room && !paths.empty?

    ENEMY_RANDOM_SPAWN_ATTEMPTS.times do
      rect = random_enemy_rect_in(paths[rand(paths.length)])
      return rect_position(rect) if valid_enemy_spawn_rect?(room, rect, archive_enemy_spawn_blockers(room) + extra_blockers)
    end

    nil
  end

  def random_sanctum_enemy_spawn extra_blockers = []
    room = @rooms[:sanctum]
    return nil unless room && rect_can_fit_enemy?(SANCTUM_LEFT_MAZE_SPAWN_AREA)

    ENEMY_RANDOM_SPAWN_ATTEMPTS.times do
      rect = random_enemy_rect_in(SANCTUM_LEFT_MAZE_SPAWN_AREA)
      return rect_position(rect) if valid_enemy_spawn_rect?(room, rect, sanctum_enemy_spawn_blockers(room) + extra_blockers)
    end

    nil
  end

  def rect_can_fit_enemy? rect
    rect[:w] >= NamelessThing::SIZE && rect[:h] >= NamelessThing::SIZE
  end

  def random_enemy_rect_in rect
    max_x = rect[:w] - NamelessThing::SIZE
    max_y = rect[:h] - NamelessThing::SIZE
    {
      x: rect[:x] + rand(max_x + 1),
      y: rect[:y] + rand(max_y + 1),
      w: NamelessThing::SIZE,
      h: NamelessThing::SIZE
    }
  end

  def rect_position rect
    { x: rect[:x], y: rect[:y] }
  end

  def valid_enemy_spawn_rect? room, rect, blockers
    return false unless rect_inside_rect?(rect, room.play_area)
    return false if blockers.any? { |blocker| rects_intersect?(rect, blocker) }
    return false if @player && distance_between(rect_center(rect), @player.center) < ENEMY_PLAYER_SPAWN_BUFFER

    true
  end

  def archive_enemy_spawn_blockers room
    room_collision_barriers(room)
  end

  def sanctum_enemy_spawn_blockers room
    room_collision_barriers(room) + room.interactables.map(&:rect)
  end

  def room_collision_barriers room
    barriers = room.barriers.dup
    room.locked_gates.each do |gate|
      barriers << gate[:rect] if key_gate_closed?(gate[:id])
    end
    barriers
  end

  def rect_inside_rect? inner, outer
    inner[:x] >= outer[:x] &&
      inner[:x] + inner[:w] <= outer[:x] + outer[:w] &&
      inner[:y] >= outer[:y] &&
      inner[:y] + inner[:h] <= outer[:y] + outer[:h]
  end

  def rect_center rect
    { x: rect[:x] + rect[:w] / 2, y: rect[:y] + rect[:h] / 2 }
  end

  def enemy_rects_for_room room_id
    @enemies.find_all { |enemy| enemy.room_id == room_id }.map(&:rect)
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
    if point_on_archive_safe_path?(@player.center)
      clear_archive_off_path_warning
      return false
    end

    @archive_off_path_started_at ||= Kernel.tick_count
    return false unless archive_off_path_warning_elapsed >= ARCHIVE_OFF_PATH_WARNING_FRAMES

    request_archive_path_reset
    true
  end

  def reset_player_to_archive_entrance
    spawn = current_room.spawn(@archive_reset_spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.stop!
    clear_archive_off_path_warning
    close_altar
    clear_interaction_text
    reset_archive_enemies
    @camera.snap_to(@player)
  end

  def reset_player_to_sanctum_exit
    spawn = current_room.spawn(:from_archive)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.stop!
    close_altar
    clear_interaction_text
    reset_sanctum_enemies
    @camera.snap_to(@player)
  end

  def clear_archive_off_path_warning
    @archive_off_path_started_at = nil
  end

  def archive_off_path_warning_active?
    @current_room_id == :archive && !!@archive_off_path_started_at && !reset_sequence_active?
  end

  def archive_off_path_warning_elapsed
    return 0 unless @archive_off_path_started_at

    Kernel.tick_count - @archive_off_path_started_at
  end

  def reset_archive_enemies
    occupied_rects = []
    @enemies.each do |enemy|
      next unless enemy.room_id == :archive

      spawn = enemy.id == :archive_bell_sacrifice ? archive_second_enemy_spawn(occupied_rects) : archive_enemy_spawn(occupied_rects)
      enemy.reset!(:archive, spawn)
      occupied_rects << enemy.rect
    end
  end

  def reset_sanctum_enemies
    occupied_rects = []
    @enemies.each do |enemy|
      next unless enemy.room_id == :sanctum

      enemy.reset!(:sanctum, sanctum_enemy_spawn(occupied_rects))
      occupied_rects << enemy.rect
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
