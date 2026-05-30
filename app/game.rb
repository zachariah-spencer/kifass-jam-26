class Room
  attr_reader :id, :world_w, :world_h, :play_area, :player_spawns, :interactables, :barriers

  def initialize id, world_w, world_h, play_area, player_spawns, interactables, barriers = []
    @id = id
    @world_w = world_w
    @world_h = world_h
    @play_area = play_area
    @player_spawns = player_spawns
    @interactables = interactables
    @barriers = barriers
  end

  def spawn spawn_id
    @player_spawns[spawn_id] || @player_spawns[:default]
  end
end

class Game
  S = WorldScale
  MAP_TILE = 128
  G = -> tile { tile * MAP_TILE }
  VIEWPORT_W = 1280
  VIEWPORT_H = 720
  WORLD_W = G[130]
  WORLD_H = G[82]
  PLAY_AREA = { x: G[3], y: G[3], w: G[124], h: G[76] }
  LEFT_EXIT_X = G[8]
  RIGHT_EXIT_X = G[122]
  LEFT_EXIT_SPAWN_X = G[13]
  RIGHT_EXIT_SPAWN_X = G[117]
  MESSAGE_DELAY_FRAMES = 3.seconds
  MESSAGE_CHARACTER_INTERVAL = 0.1.seconds
  ENDING_TEXT_COMPLETE_DELAY_FRAMES = 2.seconds
  SACRIFICE_SCRAMBLE_INTERVAL = 0.08.seconds
  SACRIFICE_SCRAMBLE_SYMBOLS = "!@#$%^&*?+=~[]{}/\\"
  ENDING_DOOR_OPEN_FRAMES = 1.2.seconds
  ENDING_PLAYER_FADE_FRAMES = 2.seconds
  ENDING_PLAYER_WALK_FRAMES = 2.2.seconds
  ENDING_FADE_BLACK_FRAMES = 1.6.seconds
  ENDING_CARD_FADE_FRAMES = 1.seconds
  ENDING_TITLE_FRAMES = 3.5.seconds
  ENDING_TITLE_CORRUPT_AFTER_FRAMES = 1.1.seconds
  RESET_HINTS = ["HINT 1", "HINT 2", "HINT 3"]
  RESET_FADE_OUT_FRAMES = 0.3.seconds
  RESET_HINT_FADE_FRAMES = 0.35.seconds
  RESET_HINT_HOLD_FRAMES = 2.seconds
  RESET_FADE_IN_FRAMES = 0.35.seconds
  ARCHIVE_PATH_RESET_FADE_FRAMES = 0.2.seconds
  ALTAR_PANEL = { x: 430, y: 190, w: 420, h: 330 }
  ALTAR_WORD_ROW_H = 42
  ROOM_FADE_OUT_FRAMES = 8
  ROOM_FADE_IN_FRAMES = 8
  INTERACTION_RADIUS = S.value(128)
  POINTER_DRAG_DEADZONE = S.value(16)
  POINTER_TAP_MAX_FRAMES = 0.25.seconds
  ARCHIVE_SAFE_PATH_TOLERANCE = S.value(18)
  ARCHIVE_SAFE_PATH_EXTRA_WIDTH = S.value(56)
  BELL_STUN_FRAMES = 3.seconds
  BELL_TOOLTIP_TEXT = "Press E or click empty space to ring the bell and stun the Nameless Thing."
  HALL_BELL_GATE = { x: G[25], y: G[37], w: G[2], h: G[3] }
  LOCKED_GATE_SPRITE_PATH = "sprites/locked_gate.png"
  FINAL_LOCKED_GATE_SPRITE_PATH = "sprites/locked_gate_final.png"
  LOCKED_GATE_FRAME_COUNT = 9
  LOCKED_GATE_FRAME_COLUMNS = 3
  LOCKED_GATE_FRAME_W = 512
  LOCKED_GATE_FRAME_H = 768
  FINAL_LOCKED_GATE_FRAME_W = 512
  FINAL_LOCKED_GATE_FRAME_H = 1280
  LOCKED_GATE_FRAME_HOLD = 5
  SANCTUM_WALL_X = G[64]
  SANCTUM_GATE_H = G[10]
  SANCTUM_KEY_GATE = { x: SANCTUM_WALL_X, y: G[36], w: G[2], h: SANCTUM_GATE_H }
  SANCTUM_KEY_GATE_SPRITE = { x: SANCTUM_WALL_X - G[1], y: G[36], w: G[4], h: SANCTUM_GATE_H }
  SANCTUM_REGULAR_ALTAR_IDS = [:sanctum_key_altar, :sanctum_memory_altar]
  SANCTUM_FINAL_ALTAR_ID = :sanctum_name_altar
  SANCTUM_ALTAR_WORDS = ["KEY", "BELL", "MIRROR"]
  PLAYER_NAME_WORD = "YOUR NAME"
  ENV_TILE_SIZE = 128
  ENV_TILE_PATH_TEMPLATE = "sprites/environment/tiles/tile%04d.png"
  ENV_TILE_PATCH_PATH = "sprites/environment/tiles/tile_patch.png"
  ENV_TILE_PATCH_SIZE = 16
  ENV_TILE_W = 1
  ENV_TILE_S = 2
  ENV_TILE_E = 4
  ENV_TILE_N = 8
  DUST_PARTICLE_DENSITY_PERCENT = 50
  DUST_PARTICLE_CELL_SIZE = 256
  DUST_PARTICLE_ALPHA_MIN = 42
  DUST_PARTICLE_ALPHA_MAX = 96

  attr_accessor :player_name
  attr_reader :player, :camera, :learned_words, :sacrificed_words, :sacrificed_object_ids, :current_room_id, :enemy

  def initialize
    @player_name = PLAYER_NAME_WORD
    restart
  end

  def restart
    @rooms = build_rooms
    @current_room_id = :hall
    room = current_room
    spawn = room.spawn(:default)
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @player = Player.new(spawn[:x], spawn[:y])
    @enemy = NamelessThing.new(:archive, archive_enemy_spawn[:x], archive_enemy_spawn[:y])
    @learned_words = []
    @learned_object_ids = []
    @learned_word_sources = {}
    @sacrificed_words = []
    @sacrificed_object_ids = []
    @altar_open = false
    @active_altar = nil
    @room_transition = nil
    @reset_sequence = nil
    @archive_reset_spawn_id = :from_hall
    @camera.snap_to(@player)
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
    @bell_tooltip_shown = false
    @bell_tooltip_until = nil
    @pointer_gesture = nil
    @touch_gestures = {}
    @touch_movement_id = nil
    @pointer_taps = []
    @pointer_tap = nil
    @pointer_drag_vector = nil
    @env_tile_cache = {}
    @key_gate_animation_started_at = nil
    @key_gate_animation_direction = nil
    @key_gate_animation_from_frame = 0
    @key_gate_frame = 0
    @ending_sequence_triggered = false
    @ending_phase = nil
    @ending_phase_started_at = nil
    @ending_player_start = nil
    @ending_player_target = nil
    @ending_title_corruptor = nil
    @ending_title_started_at = nil
  end

  def build_rooms
    {
      hall: build_hall_room,
      archive: build_archive_room,
      sanctum: build_sanctum_room
    }
  end

  def build_hall_room
    Room.new(
      :hall,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: WORLD_W / 2 - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_archive: { x: RIGHT_EXIT_SPAWN_X - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Bell.new(G[14] - Bell::W / 2, G[40] - Bell::H / 2, :hall_bells),
        Lamp.new(G[10] - Lamp::SIZE / 2, G[33] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[120] - Lamp::SIZE / 2, G[33] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[10] - Lamp::SIZE / 2, G[10] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[120] - Lamp::SIZE / 2, G[72] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[65] - Lamp::SIZE / 2, G[55] - Lamp::SIZE / 2, :lamp),
        Altar.new(G[65] - Altar::W / 2, G[36] - Altar::H / 2, :hall_altar),
        Exit.new(RIGHT_EXIT_X - Exit::W / 2, WORLD_H / 2 - Exit::H / 2, :hall_to_archive, :archive, :from_hall, unlock_altar_id: :hall_altar)
      ],
      hall_bell_alcove_walls
    )
  end

  def hall_bell_alcove_walls
    [
      { x: G[5], y: G[31], w: G[22], h: G[2] },
      { x: G[5], y: G[47], w: G[22], h: G[2] },
      { x: G[5], y: G[31], w: G[2], h: G[18] },
      { x: G[25], y: G[31], w: G[2], h: G[6] },
      { x: G[25], y: G[40], w: G[2], h: G[9] }
    ]
  end

  def build_archive_room
    Room.new(
      :archive,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: G[14] - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_hall: { x: LEFT_EXIT_SPAWN_X - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_sanctum: { x: RIGHT_EXIT_SPAWN_X - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Lamp.new(G[16] - Lamp::SIZE / 2, G[55] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[65] - Lamp::SIZE / 2, G[24] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[36] - Lamp::SIZE / 2, G[56] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[55] - Lamp::SIZE / 2, G[42] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[69] - Lamp::SIZE / 2, G[31] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[86] - Lamp::SIZE / 2, G[45] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[57] - Lamp::SIZE / 2, G[67] - Lamp::SIZE / 2, :lamp),
        Mirror.new(G[17] - Mirror::W / 2, G[49] - Mirror::H / 2, :archive_mirror),
        Altar.new(G[22] - Altar::W / 2, G[36] - Altar::H / 2, :archive_altar),
        ArchiveKey.new(G[72] - ArchiveKey::W / 2, G[70] - ArchiveKey::H / 2, :archive_key),
        Exit.new(LEFT_EXIT_X - Exit::W / 2, WORLD_H / 2 - Exit::H / 2, :archive_to_hall, :hall, :from_archive),
        Exit.new(RIGHT_EXIT_X - Exit::W / 2, WORLD_H / 2 - Exit::H / 2, :archive_to_sanctum, :sanctum, :from_archive, unlock_altar_id: :archive_altar)
      ]
    )
  end

  def build_sanctum_room
    Room.new(
      :sanctum,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: G[14] - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_archive: { x: LEFT_EXIT_SPAWN_X - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Lamp.new(G[18] - Lamp::SIZE / 2, G[55] - Lamp::SIZE / 2, :lamp),
        Lamp.new(G[110] - Lamp::SIZE / 2, G[58] - Lamp::SIZE / 2, :lamp),
        Altar.new(G[85] - Altar::W / 2, G[53] - Altar::H / 2, :sanctum_key_altar),
        Altar.new(G[85] - Altar::W / 2, G[30] - Altar::H / 2, :sanctum_memory_altar),
        NameAltar.new(G[100] - NameAltar::W / 2, G[41] - NameAltar::H / 2, SANCTUM_FINAL_ALTAR_ID),
        FinalDoor.new(G[120] - FinalDoor::W / 2, G[41] - FinalDoor::H / 2, :sanctum_final_door),
        Exit.new(LEFT_EXIT_X - Exit::W / 2, WORLD_H / 2 - Exit::H / 2, :sanctum_to_archive, :archive, :from_sanctum)
      ],
      sanctum_walls
    )
  end

  def sanctum_walls
    [
      {
        x: SANCTUM_KEY_GATE_SPRITE[:x],
        y: PLAY_AREA[:y],
        w: SANCTUM_KEY_GATE_SPRITE[:w],
        h: SANCTUM_KEY_GATE[:y] - PLAY_AREA[:y]
      },
      {
        x: SANCTUM_KEY_GATE_SPRITE[:x],
        y: SANCTUM_KEY_GATE[:y] + SANCTUM_KEY_GATE[:h],
        w: SANCTUM_KEY_GATE_SPRITE[:w],
        h: PLAY_AREA[:y] + PLAY_AREA[:h] - (SANCTUM_KEY_GATE[:y] + SANCTUM_KEY_GATE[:h])
      }
    ]
  end

  def current_room
    @rooms[@current_room_id]
  end

  def interactables
    current_room.interactables
  end

  def update args
    return update_ending_sequence(args) if ending_sequence_triggered?
    return update_reset_sequence if reset_sequence_active?

    update_room_transition
    return if room_transition_active?

    update_pointer_gesture(args)
    handle_debug_input(args)
    handle_interaction(args)
    update_interaction_text
    interactables.each { |interactable| interactable.update(args) }
    @player.update(args, current_room.play_area, active_barriers, pointer_movement_vector)
    close_altar_if_player_left_range
    return if reset_player_if_off_archive_path

    return if update_enemy(args)

    @camera.follow(@player)
    handle_exit_transition
  end

  def handle_interaction args
    taps = pointer_taps
    tap = taps.first
    return handle_altar_selection(tap) if @altar_open && tap
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
    @current_room_id = room_id
    room = current_room
    @archive_reset_spawn_id = archive_reset_spawn_for(spawn_id) if room_id == :archive
    spawn = room.spawn(spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @enemy.reset!(:archive, archive_enemy_spawn) if room_id == :archive
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @camera.snap_to(@player)
  end

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

  def interaction_text_for interactable
    return nil unless interactable
    return interactable.sacrificed_interaction_text if interactable.word && @sacrificed_words.include?(interactable.word)
    return interactable.sacrificed_interaction_text if sacrificed_object?(interactable.id)
    return interactable.interaction_text unless interactable.word
    return interactable.interaction_text if @learned_object_ids.include?(interactable.id)

    unless @learned_words.include?(interactable.word)
      @learned_words << interactable.word
      start_key_gate_animation(:open) if interactable.word == "KEY"
      @player.light_size = 2048 if interactable.id == :lamp
      show_bell_tooltip if interactable.word == "BELL"
    end
    @learned_object_ids << interactable.id
    @learned_word_sources[interactable.word] = interactable.id
    "#{interactable.interaction_text} You remember that this is a #{interactable.word}."
  end

  def open_altar altar
    return "The altar is spent." if altar.sacrificed?

    @active_altar = altar
    @altar_open = true
    sacrificeable_words.empty? ? "The altar waits for a name." : "Choose a name to sacrifice."
  end

  def handle_altar_selection click
    word = altar_word_at(click)

    if word
      sacrifice_word(word)
    else
      close_altar
      set_interaction_text(nil)
    end
  end

  def sacrifice_word word
    return unless sacrificeable_words.include?(word)

    active_altar_id = @active_altar ? @active_altar.id : nil
    if player_name_word?(word)
      @sacrificed_words << PLAYER_NAME_WORD unless @sacrificed_words.include?(PLAYER_NAME_WORD)
      @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
      @active_altar.sacrifice! if @active_altar
      close_altar
      set_interaction_text("You sacrificed #{word}.")
      start_ending_sequence
      return
    end

    @player.light_size = 1096 if word == "LAMP"
    start_key_gate_animation(:close) if word == "KEY"

    @learned_words.delete(word)
    @sacrificed_words << word unless @sacrificed_words.include?(word)
    @enemy.clear_stun! if word == "BELL"

    @learned_word_sources.delete(word)
    all_interactables.each do |interactable|
      next unless interactable.word == word

      @sacrificed_object_ids << interactable.id unless @sacrificed_object_ids.include?(interactable.id)
      interactable.sacrifice!
    end

    unlock_exits_for(active_altar_id)
    @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
    @active_altar.sacrifice! if @active_altar
    close_altar
    set_interaction_text("You sacrificed #{word}.")
  end

  def show_bell_tooltip
    return if @bell_tooltip_shown

    @bell_tooltip_shown = true
    @bell_tooltip_until = Kernel.tick_count + BELL_STUN_FRAMES
  end

  def unlock_exits_for altar_id
    return unless altar_id

    all_interactables.each do |interactable|
      next unless interactable.is_a?(Exit)
      next unless interactable.unlock_altar_id == altar_id

      interactable.unlock!
    end
  end

  def sacrificeable_words
    return sanctum_name_sacrifice_words if @active_altar && @active_altar.id == SANCTUM_FINAL_ALTAR_ID
    return sanctum_regular_sacrifice_words if @active_altar && sanctum_regular_altar?(@active_altar)
    return @learned_words.select { |word| archive_sacrifice_word?(word) } if @active_altar && @active_altar.id == :archive_altar

    @learned_words
  end

  def sanctum_regular_sacrifice_words
    words = @learned_words.select { |word| SANCTUM_ALTAR_WORDS.include?(word) }
    return words.select { |word| word == "KEY" } if sanctum_regular_altar_spent_count == 1 && !word_sacrificed?("KEY")
    return words.reject { |word| word == "KEY" } if word_sacrificed?("KEY")

    words
  end

  def sanctum_name_sacrifice_words
    sanctum_final_altar_active? ? [player_name_word] : []
  end

  def player_name_word
    @player_name.to_s.strip.empty? ? PLAYER_NAME_WORD : @player_name
  end

  def player_name_word? word
    word == PLAYER_NAME_WORD || word == player_name_word
  end

  def sanctum_regular_altar? altar
    SANCTUM_REGULAR_ALTAR_IDS.include?(altar.id)
  end

  def sanctum_regular_altar_spent_count
    SANCTUM_REGULAR_ALTAR_IDS.count { |altar_id| sacrificed_object?(altar_id) }
  end

  def sanctum_final_altar_active?
    sanctum_regular_altar_spent_count == SANCTUM_REGULAR_ALTAR_IDS.length
  end

  def archive_sacrifice_word? word
    word == "MIRROR" || word == "KEY"
  end

  def sacrificed_object? object_id
    @sacrificed_object_ids.include?(object_id)
  end

  def all_interactables
    objects = []
    @rooms.each_value do |room|
      room.interactables.each { |interactable| objects << interactable }
    end
    objects
  end

  def close_altar
    @altar_open = false
    @active_altar = nil
  end

  def close_altar_if_player_left_range
    return unless @altar_open && @active_altar
    return if nearby_interactable?(@active_altar)

    close_altar
    clear_interaction_text
  end

  def altar_word_at point
    sacrificeable_words.each_with_index do |word, index|
      return word if point_inside_rect?(point, altar_word_rect(index))
    end

    nil
  end

  def altar_word_rect index
    {
      x: ALTAR_PANEL[:x] + 32,
      y: ALTAR_PANEL[:y] + ALTAR_PANEL[:h] - 114 - index * ALTAR_WORD_ROW_H,
      w: ALTAR_PANEL[:w] - 64,
      h: 34
    }
  end

  def point_inside_rect? point, rect
    point_x = point.is_a?(Hash) ? point[:x] : point.x
    point_y = point.is_a?(Hash) ? point[:y] : point.y
    point_x >= rect[:x] && point_x <= rect[:x] + rect[:w] && point_y >= rect[:y] && point_y <= rect[:y] + rect[:h]
  end

  def handle_exit_transition
    exit = nearby_interactables.find { |interactable| interactable.is_a?(Exit) && rects_intersect?(@player.rect, interactable.rect) }
    text = exit&.interact(self)
    set_interaction_text(text) if text && text != @interaction_text
  end

  def rects_intersect? first, second
    first[:x] < second[:x] + second[:w] &&
      first[:x] + first[:w] > second[:x] &&
      first[:y] < second[:y] + second[:h] &&
      first[:y] + first[:h] > second[:y]
  end

  def distance_between first, second
    dx = second[:x] - first[:x]
    dy = second[:y] - first[:y]
    Math.sqrt(dx * dx + dy * dy)
  end

  def set_interaction_text text
    @interaction_text = text
    @interaction_started_at = text ? Kernel.tick_count : nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = sacrificed_word_from_text(text)
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
  end

  def start_ending_sequence
    @ending_sequence_triggered = true
    @ending_phase = :sacrifice_message
    @ending_phase_started_at = Kernel.tick_count
    clear_pointer_gesture
    @player.stop!
  end

  def update_ending_sequence args
    update_interaction_text(true)
    interactables.each { |interactable| interactable.update(args) }
    @player.stop! unless @ending_phase == :player_walks
    advance_ending_phase if ending_phase_complete?
    update_ending_player_walk if @ending_phase == :player_walks
    @camera.follow(@player) if @ending_phase == :player_walks
  end

  def advance_ending_phase
    case @ending_phase
    when :sacrifice_message
      clear_interaction_text
      set_ending_phase(:door_opens)
    when :door_opens
      prepare_ending_walk
      @player.force_run_animation!
      set_ending_phase(:player_walks)
    when :player_walks
      @player.force_idle_animation!
      set_ending_phase(:player_fades)
    when :player_fades
      set_ending_phase(:fade_black)
    when :fade_black
      set_ending_phase(:final_text_fade_in)
    when :final_text_fade_in
      set_ending_phase(:final_text)
    when :final_text
      set_ending_phase(:final_text_fade_out)
    when :final_text_fade_out
      @ending_title_corruptor = TextCorruptor.new("EPITHET")
      @ending_title_started_at = Kernel.tick_count
      set_ending_phase(:title_fade_in)
    when :title_fade_in
      set_ending_phase(:title_card)
    when :title_card
      set_ending_phase(:title_fade_out)
    when :title_fade_out
      set_ending_phase(:done)
    end
  end

  def set_ending_phase phase
    @ending_phase = phase
    @ending_phase_started_at = Kernel.tick_count
  end

  def ending_phase_complete?
    case @ending_phase
    when :sacrifice_message
      final_sacrifice_message_complete?
    when :door_opens
      ending_phase_elapsed >= ENDING_DOOR_OPEN_FRAMES
    when :player_fades
      ending_phase_elapsed >= ENDING_PLAYER_FADE_FRAMES
    when :player_walks
      ending_phase_elapsed >= ENDING_PLAYER_WALK_FRAMES
    when :fade_black
      ending_phase_elapsed >= ENDING_FADE_BLACK_FRAMES
    when :final_text_fade_in, :final_text_fade_out, :title_fade_in, :title_fade_out
      ending_phase_elapsed >= ENDING_CARD_FADE_FRAMES
    when :final_text
      final_text_ready_to_fade_out?
    when :title_card
      ending_phase_elapsed >= ENDING_TITLE_FRAMES
    else
      false
    end
  end

  def ending_phase_elapsed
    Kernel.tick_count - @ending_phase_started_at
  end

  def final_sacrifice_message_complete?
    return false unless @interaction_text && @interaction_finished_at
    return false unless sacrifice_scramble_complete?

    Kernel.tick_count - @interaction_finished_at >= MESSAGE_DELAY_FRAMES
  end

  def sacrifice_scramble_complete?
    return true unless @interaction_sacrificed_word

    non_space_count = @interaction_sacrificed_word.length - @interaction_sacrificed_word.count(" ")
    Kernel.tick_count - @interaction_finished_at >= non_space_count * SACRIFICE_SCRAMBLE_INTERVAL
  end

  def prepare_ending_walk
    door = final_door
    return unless door

    @ending_player_start = { x: @player.x, y: @player.y }
    @ending_player_target = {
      x: door.center[:x] - @player.w / 2,
      y: door.center[:y] - @player.h / 2
    }
    @player.face_toward_x(@ending_player_target[:x])
  end

  def update_ending_player_walk
    return unless @ending_player_start && @ending_player_target

    progress = (ending_phase_elapsed.to_f / ENDING_PLAYER_WALK_FRAMES).clamp(0, 1)
    @player.x = @ending_player_start[:x].lerp(@ending_player_target[:x], progress)
    @player.y = @ending_player_start[:y].lerp(@ending_player_target[:y], progress)
  end

  def final_door
    interactables.find { |interactable| interactable.is_a?(FinalDoor) }
  end

  def update_interaction_text hold_final_sacrifice = false
    return unless @interaction_text

    if visible_interaction_text.length == @interaction_text.length
      @interaction_finished_at ||= Kernel.tick_count
      clear_interaction_text if !hold_final_sacrifice && Kernel.tick_count - @interaction_finished_at >= MESSAGE_DELAY_FRAMES
    end
  end

  def clear_interaction_text
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
  end

  def visible_interaction_text
    return "" unless @interaction_text && @interaction_started_at

    elapsed = Kernel.tick_count - @interaction_started_at
    character_count = elapsed.idiv(MESSAGE_CHARACTER_INTERVAL) + 1
    current_interaction_text[0, character_count.clamp(0, @interaction_text.length)]
  end

  def current_interaction_text
    return @interaction_text unless @interaction_sacrificed_word && @interaction_finished_at

    @interaction_text.sub(@interaction_sacrificed_word, scrambled_sacrificed_word)
  end

  def scrambled_sacrificed_word
    elapsed = Kernel.tick_count - @interaction_finished_at
    @interaction_scramble_order ||= random_sacrifice_scramble_order(@interaction_sacrificed_word)
    scramble_count = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL).clamp(0, @interaction_scramble_order.length)
    scramble_tick = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL)
    return @interaction_scrambled_word if @interaction_scrambled_at == scramble_tick && @interaction_scrambled_word

    @interaction_scrambled_word ||= @interaction_sacrificed_word.dup
    scramble_count.times do |index|
      word_index = @interaction_scramble_order[index]
      @interaction_scrambled_word[word_index] = SACRIFICE_SCRAMBLE_SYMBOLS[rand(SACRIFICE_SCRAMBLE_SYMBOLS.length)]
    end
    @interaction_scrambled_at = scramble_tick

    @interaction_scrambled_word
  end

  def random_sacrifice_scramble_order word = @interaction_sacrificed_word
    order = []
    word.length.times do |index|
      next if word[index] == " "

      insert_at = order.length == 0 ? 0 : rand(order.length + 1)
      order.insert(insert_at, index)
    end

    order
  end

  def sacrificed_word_from_text text
    return nil unless text

    prefix = "You sacrificed "
    suffix = "."
    return nil unless text.start_with?(prefix) && text.end_with?(suffix)

    text[prefix.length, text.length - prefix.length - suffix.length]
  end

  def render args
    if ending_card_screen?
      render_ending_card_background(args)
    else
      render_lit_scene(args)
    end
    render_ui(args)
    render_ending(args)
    render_room_transition(args)
    render_reset_sequence(args)
  end

  def ending_card_screen?
    return false unless ending_sequence_triggered?

    [
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
  end

  def render_ending_card_background args
    args.outputs.sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
  end

  def render_lit_scene args
    args.outputs[:scene].set(w: Grid.w, h: Grid.h, background_color: [10, 9, 14, 255])
    args.outputs[:darkness].set(w: Grid.w, h: Grid.h, background_color: [0, 0, 0, 0])

    render_floor(args, args.outputs[:scene])
    render_room_barriers(args, args.outputs[:scene])
    render_archive_safe_paths(args, args.outputs[:scene])
    interactables.each { |interactable| render_interactable(args, interactable, args.outputs[:scene]) }
    nearby_interactables.each { |interactable| interactable.render_highlight(args, args.outputs[:scene], @camera) unless input_locked? }
    @enemy.render(args, args.outputs[:scene], @camera) if @enemy.room_id == @current_room_id
    @player.render(args, args.outputs[:scene], @camera, player_alpha)
    render_ambient_dust(args, args.outputs[:scene])
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    @enemy.render_light(args, args.outputs[:darkness], @camera) if @enemy.room_id == @current_room_id
    @player.render_light(args, args.outputs[:darkness], @camera)

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :scene }
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :darkness }
  end

  def render_interactable args, interactable, outputs
    if interactable.is_a?(FinalDoor)
      interactable.render(args, outputs, @camera, final_door_open?)
    else
      interactable.render(args, outputs, @camera)
    end
  end

  def render_ambient_dust args, outputs = args.outputs
    visible = {
      x: @camera.x,
      y: @camera.y,
      w: @camera.visible_w,
      h: @camera.visible_h
    }
    min_col = (visible[:x] / DUST_PARTICLE_CELL_SIZE).floor
    max_col = ((visible[:x] + visible[:w]) / DUST_PARTICLE_CELL_SIZE).ceil
    min_row = (visible[:y] / DUST_PARTICLE_CELL_SIZE).floor
    max_row = ((visible[:y] + visible[:h]) / DUST_PARTICLE_CELL_SIZE).ceil
    tick = Kernel.tick_count

    dust = []
    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        seed = dust_particle_seed(col, row)
        next unless seed % 100 < DUST_PARTICLE_DENSITY_PERCENT

        particle = ambient_dust_particle(col, row, seed, tick)
        screen_rect = @camera.screen_rect(particle)
        next if screen_rect[:x] < -6 || screen_rect[:x] > Grid.w + 6
        next if screen_rect[:y] < -6 || screen_rect[:y] > Grid.h + 6

        dust << screen_rect.merge(
          path: :solid,
          r: 255,
          g: 255,
          b: 255,
          a: particle[:a]
        )
      end
    end
    outputs.primitives << dust
  end

  def ambient_dust_particle col, row, seed, tick
    phase = seed % 360
    slow_phase = (tick + phase) * Math::PI * 2 / 420
    fast_phase = (tick + phase * 3) * Math::PI * 2 / 260
    base_x = col * DUST_PARTICLE_CELL_SIZE + seed % DUST_PARTICLE_CELL_SIZE
    base_y = row * DUST_PARTICLE_CELL_SIZE + seed.idiv(7) % DUST_PARTICLE_CELL_SIZE
    drift_y = (tick * (0.012 + (seed % 7) * 0.002)) % DUST_PARTICLE_CELL_SIZE
    size = seed % 5 == 0 ? 10 : 8
    alpha = DUST_PARTICLE_ALPHA_MIN + seed % (DUST_PARTICLE_ALPHA_MAX - DUST_PARTICLE_ALPHA_MIN)

    {
      x: base_x + Math.sin(slow_phase) * 18 + Math.sin(fast_phase) * 5,
      y: base_y + Math.cos(slow_phase) * 12 + drift_y,
      w: size,
      h: size,
      a: (alpha + Math.sin(fast_phase) * 18).to_i.clamp(DUST_PARTICLE_ALPHA_MIN, DUST_PARTICLE_ALPHA_MAX)
    }
  end

  def dust_particle_seed col, row
    ((col * 73_856_093) ^ (row * 19_349_663) ^ 83_492_791).abs
  end

  def final_door_open?
    return false unless ending_sequence_triggered?

    [
      :door_opens,
      :player_fades,
      :player_walks,
      :fade_black,
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
  end

  def player_alpha
    return 255 unless ending_sequence_triggered?
    return 0 if [
      :fade_black,
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
    return 255 unless @ending_phase == :player_fades

    (255 - ending_phase_elapsed * 210 / ENDING_PLAYER_FADE_FRAMES).clamp(45, 255)
  end

  def render_floor args, outputs = args.outputs
    play_area = @camera.screen_rect(current_room.play_area)
    outputs.sprites << Render.solid(play_area, :stone, a: 85)
    render_env_tiles(outputs, cached_env_tile_cells([:room_outline, current_room.id]) { rect_outline_cells(current_room.play_area) })
  end

  def render_room_barriers args, outputs = args.outputs
    render_env_tiles(
      outputs,
      cached_env_tile_cells([:barriers, current_room.id]) do
        current_room.barriers.flat_map { |barrier| rect_fill_cells(barrier) }.uniq
      end
    )

    render_hall_locked_gate(outputs) if current_room.id == :hall
    render_sanctum_locked_gate(outputs) if current_room.id == :sanctum
  end

  def cached_env_tile_cells key
    @env_tile_cache[key] ||= env_tile_layer(yield)
  end

  def rect_outline_cells rect
    min_col, max_col, min_row, max_row = env_cell_bounds(rect)
    cells = []

    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        next unless col == min_col || col == max_col || row == min_row || row == max_row

        cells << [col, row]
      end
    end

    cells
  end

  def rect_fill_cells rect
    min_col, max_col, min_row, max_row = env_cell_bounds(rect)
    cells = []

    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        cells << [col, row]
      end
    end

    cells
  end

  def env_cell_bounds rect
    [
      (rect[:x] / ENV_TILE_SIZE).floor,
      ((rect[:x] + rect[:w] - 1) / ENV_TILE_SIZE).floor,
      (rect[:y] / ENV_TILE_SIZE).floor,
      ((rect[:y] + rect[:h] - 1) / ENV_TILE_SIZE).floor
    ]
  end

  def render_env_tiles outputs, layer, alpha: 255
    cells = layer[:cells]
    occupied = layer[:occupied]
    tile_size = ENV_TILE_SIZE * Camera::ZOOM

    cells.each do |col, row|
      world_rect = {
        x: col * ENV_TILE_SIZE,
        y: row * ENV_TILE_SIZE,
        w: ENV_TILE_SIZE,
        h: ENV_TILE_SIZE
      }
      tile_rect = @camera.screen_rect(world_rect)
      outputs.sprites << tile_rect.merge(
        path: env_tile_path(env_tile_mask(col, row, occupied)),
        w: tile_size,
        h: tile_size,
        a: alpha
      )
    end

    render_env_tile_patches(outputs, layer[:patches], alpha: alpha)
  end

  def env_tile_mask col, row, occupied
    return 0 if env_tile_internal?(col, row, occupied)

    mask = 0
    mask += ENV_TILE_N unless occupied[[col, row + 1]]
    mask += ENV_TILE_E unless occupied[[col + 1, row]]
    mask += ENV_TILE_S unless occupied[[col, row - 1]]
    mask += ENV_TILE_W unless occupied[[col - 1, row]]
    mask
  end

  def env_tile_layer cells
    occupied = cells.each_with_object({}) { |cell, lookup| lookup[cell] = true }
    {
      cells: occupied.keys.reject { |col, row| env_tile_internal?(col, row, occupied) },
      occupied: occupied,
      patches: env_inside_corner_patches(occupied)
    }
  end

  def env_tile_internal? col, row, occupied
    occupied[[col, row + 1]] &&
      occupied[[col + 1, row]] &&
      occupied[[col, row - 1]] &&
      occupied[[col - 1, row]]
  end

  def render_env_tile_patches outputs, patches, alpha: 255
    patch_size = ENV_TILE_PATCH_SIZE * Camera::ZOOM

    patches.each do |patch|
      patch_rect = @camera.screen_rect(
        x: patch[:x],
        y: patch[:y],
        w: ENV_TILE_PATCH_SIZE,
        h: ENV_TILE_PATCH_SIZE
      )
      outputs.sprites << patch_rect.merge(
        path: ENV_TILE_PATCH_PATH,
        w: patch_size,
        h: patch_size,
        a: alpha
      )
    end
  end

  def env_inside_corner_patches occupied
    points = {}

    occupied.each_key do |col, row|
      points[[col, row]] = true
      points[[col + 1, row]] = true
      points[[col, row + 1]] = true
      points[[col + 1, row + 1]] = true
    end

    points.each_key.flat_map do |col, row|
      ne = occupied[[col, row]]
      nw = occupied[[col - 1, row]]
      sw = occupied[[col - 1, row - 1]]
      se = occupied[[col, row - 1]]
      next [] unless [ne, nw, sw, se].count(true) == 3

      env_inside_corner_patch(col, row, ne, nw, sw, se)
    end
  end

  def env_inside_corner_patch col, row, ne, nw, sw, se
    x = col * ENV_TILE_SIZE
    y = row * ENV_TILE_SIZE
    p = ENV_TILE_PATCH_SIZE

    if !ne
      [{ x: x - p, y: y - p }]
    elsif !nw
      [{ x: x, y: y - p }]
    elsif !sw
      [{ x: x, y: y }]
    elsif !se
      [{ x: x - p, y: y }]
    else
      []
    end
  end

  def env_tile_path mask
    ENV_TILE_PATH_TEMPLATE % mask
  end

  def render_hall_locked_gate outputs
    render_locked_gate(
      HALL_BELL_GATE,
      outputs,
      path: LOCKED_GATE_SPRITE_PATH,
      frame_w: LOCKED_GATE_FRAME_W,
      frame_h: LOCKED_GATE_FRAME_H
    )
  end

  def render_sanctum_locked_gate outputs
    render_locked_gate(
      SANCTUM_KEY_GATE_SPRITE,
      outputs,
      path: FINAL_LOCKED_GATE_SPRITE_PATH,
      frame_w: FINAL_LOCKED_GATE_FRAME_W,
      frame_h: FINAL_LOCKED_GATE_FRAME_H
    )
  end

  def render_locked_gate gate, outputs, path:, frame_w:, frame_h:, reverse_frames: false
    update_key_gate_frame

    gate_rect = @camera.screen_rect(gate)
    sprite_frame = reverse_frames ? LOCKED_GATE_FRAME_COUNT - 1 - @key_gate_frame : @key_gate_frame
    outputs.sprites << gate_rect.merge(
      path: path,
      tile_x: sprite_frame % LOCKED_GATE_FRAME_COLUMNS * frame_w,
      tile_y: sprite_frame.idiv(LOCKED_GATE_FRAME_COLUMNS) * frame_h,
      tile_w: frame_w,
      tile_h: frame_h
    )
  end

  def render_archive_safe_paths args, outputs = args.outputs
    return unless @current_room_id == :archive
    return unless @learned_words.include?("MIRROR")
    return if @sacrificed_words.include?("MIRROR")

    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 120)
    render_env_tiles(
      outputs,
      cached_env_tile_cells(:archive_safe_paths) do
        archive_safe_paths.flat_map { |path| rect_fill_cells(path) }.uniq
      end,
      alpha: (55 + pulse * 18).to_i
    )
  end

  def render_ui args
    return render_ending_ui(args) if ending_sequence_triggered? && @ending_phase != :sacrifice_message

    # args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    render_learned_words(args)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    render_bell_tooltip(args)
    render_altar(args) if @altar_open
    args.outputs.labels << Render.label(36, 40, "Press R to forget it all...", :ash, size_enum: -1)
  end

  def render_bell_tooltip args
    return unless @bell_tooltip_until
    return if Kernel.tick_count >= @bell_tooltip_until

    panel = { x: 286, y: 92, w: 708, h: 44 }
    args.outputs.sprites << Render.solid(panel, :void, a: 210)
    args.outputs.borders << panel.merge(**Render.color(:brass), a: 220)
    args.outputs.labels << Render.label(640, 120, BELL_TOOLTIP_TEXT, :flame, size_enum: 0, alignment_enum: 1)
  end

  def render_learned_words args
    args.outputs.labels << Render.label(1080, 694, "LEARNED", :ash, size_enum: 1)

    if @learned_words.empty?
      args.outputs.labels << Render.label(1080, 664, "none", :ash, size_enum: -1)
      return
    end

    @learned_words.each_with_index do |word, index|
      args.outputs.labels << Render.label(1080, 664 - index * 24, word, :ember, size_enum: 0)
    end
  end

  def render_altar args
    args.outputs.sprites << Render.solid({ x: 0, y: 0, w: Grid.w, h: Grid.h }, :void, a: 150)
    args.outputs.sprites << Render.solid(ALTAR_PANEL, :stone)
    args.outputs.borders << ALTAR_PANEL.merge(**Render.color(:brass))
    args.outputs.labels << Render.label(640, 478, "SACRIFICE A NAME", :ash, size_enum: 2, alignment_enum: 1)

    if sacrificeable_words.empty?
      args.outputs.labels << Render.label(640, 388, "No learned names.", :ash, size_enum: 0, alignment_enum: 1)
      args.outputs.labels << Render.label(640, 246, "Click away to close.", :ash, size_enum: -1, alignment_enum: 1)
      return
    end

    sacrificeable_words.each_with_index do |word, index|
      rect = altar_word_rect(index)
      args.outputs.sprites << Render.solid(rect, :wall)
      args.outputs.borders << rect.merge(**Render.color(:ember))
      args.outputs.labels << Render.label(rect[:x] + 18, rect[:y] + 24, word, :ember, size_enum: 0)
    end
  end

  def render_room_transition args
    return unless @room_transition

    elapsed = Kernel.tick_count - @room_transition[:started_at]
    alpha = if @room_transition[:phase] == :fade_out
              elapsed * 255 / ROOM_FADE_OUT_FRAMES
            else
              255 - elapsed * 255 / ROOM_FADE_IN_FRAMES
    end
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha.clamp(0, 255) }
  end

  def render_reset_sequence args
    return unless reset_sequence_active?

    black_alpha = reset_black_alpha
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: black_alpha } if black_alpha > 0

    hint_alpha = reset_hint_alpha
    return if hint_alpha <= 0

    args.outputs.labels << Render.label(640, 360, @reset_sequence[:hint], :ash, size_enum: 3, alignment_enum: 1, a: hint_alpha)
  end

  def reset_black_alpha
    elapsed = reset_sequence_elapsed
    case @reset_sequence[:phase]
    when :fade_out
      (elapsed * 255 / reset_fade_out_frames).clamp(0, 255)
    when :fade_in
      (255 - elapsed * 255 / reset_fade_in_frames).clamp(0, 255)
    else
      255
    end
  end

  def reset_hint_alpha
    return 0 unless @reset_sequence[:show_hint]

    elapsed = reset_sequence_elapsed
    case @reset_sequence[:phase]
    when :hint_fade_in
      (elapsed * 255 / RESET_HINT_FADE_FRAMES).clamp(0, 255)
    when :hint_hold
      255
    when :hint_fade_out
      (255 - elapsed * 255 / RESET_HINT_FADE_FRAMES).clamp(0, 255)
    else
      0
    end
  end

  def render_ending args
    return unless ending_sequence_triggered?

    alpha = ending_black_alpha
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha } if alpha > 0
  end

  def ending_black_alpha
    case @ending_phase
    when :fade_black
      (ending_phase_elapsed * 255 / ENDING_FADE_BLACK_FRAMES).clamp(0, 255)
    when :final_text_fade_in, :title_fade_in
      (255 - ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text_fade_out, :title_fade_out
      (ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :done
      255
    else
      0
    end
  end

  def render_ending_ui args
    alpha = ending_card_text_alpha
    case @ending_phase
    when :final_text_fade_in, :final_text, :final_text_fade_out
      lines = visible_final_text_lines
      args.outputs.labels << Render.label(640, 430, lines[0], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
      args.outputs.labels << Render.label(640, 360, lines[1], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
      args.outputs.labels << Render.label(640, 290, lines[2], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
    when :title_fade_in, :title_card, :title_fade_out
      text = ending_title_text
      args.outputs.labels << Render.label(640, 374, text, :ash, size_enum: 8, alignment_enum: 1, a: alpha)
    end
  end

  def ending_card_text_alpha
    case @ending_phase
    when :final_text_fade_in, :title_fade_in
      (ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text_fade_out, :title_fade_out
      (255 - ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text, :title_card
      255
    else
      0
    end
  end

  def visible_final_text_lines
    lines = [
      "The door opens.",
      "Something leaves.",
      "It may have been you."
    ]
    return lines if @ending_phase == :final_text_fade_out

    visible_lines_for_character_count(lines, final_text_character_count)
  end

  def final_text_character_count
    elapsed = @ending_phase == :final_text ? ENDING_CARD_FADE_FRAMES + ending_phase_elapsed : ending_phase_elapsed
    elapsed.idiv(MESSAGE_CHARACTER_INTERVAL) + 1
  end

  def final_text_lines_length
    "The door opens.".length +
      "Something leaves.".length +
      "It may have been you.".length
  end

  def final_text_ready_to_fade_out?
    final_text_total_elapsed >= final_text_complete_at + ENDING_TEXT_COMPLETE_DELAY_FRAMES
  end

  def final_text_total_elapsed
    ENDING_CARD_FADE_FRAMES + ending_phase_elapsed
  end

  def final_text_complete_at
    (final_text_lines_length - 1) * MESSAGE_CHARACTER_INTERVAL
  end

  def visible_lines_for_character_count lines, character_count
    remaining = character_count
    lines.map do |line|
      visible_count = remaining.clamp(0, line.length)
      remaining -= line.length
      line[0, visible_count]
    end
  end

  def ending_title_text
    return "EPITHET" unless @ending_title_corruptor
    title_elapsed = Kernel.tick_count - @ending_title_started_at
    return "EPITHET" if title_elapsed < ENDING_TITLE_CORRUPT_AFTER_FRAMES

    elapsed = title_elapsed - ENDING_TITLE_CORRUPT_AFTER_FRAMES
    @ending_title_corruptor.text(elapsed)
  end
end

class TextCorruptor
  def initialize text
    @text = text
    @order = []
    text.length.times do |index|
      next if text[index] == " "

      insert_at = @order.length == 0 ? 0 : rand(@order.length + 1)
      @order.insert(insert_at, index)
    end
    @scrambled_text = text.dup
    @scrambled_at = nil
  end

  def text elapsed
    scramble_count = elapsed.idiv(Game::SACRIFICE_SCRAMBLE_INTERVAL).clamp(0, @order.length)
    scramble_tick = elapsed.idiv(Game::SACRIFICE_SCRAMBLE_INTERVAL)
    return @scrambled_text if @scrambled_at == scramble_tick

    scramble_count.times do |index|
      word_index = @order[index]
      @scrambled_text[word_index] = Game::SACRIFICE_SCRAMBLE_SYMBOLS[rand(Game::SACRIFICE_SCRAMBLE_SYMBOLS.length)]
    end
    @scrambled_at = scramble_tick
    @scrambled_text
  end
end
