class Game
  S = WorldScale
  MAP_TILE = 128
  G = -> tile { tile * MAP_TILE }
  VIEWPORT_W = 1280
  VIEWPORT_H = 720
  WORLD_W = G[130]
  WORLD_H = G[82]
  PLAY_AREA = { x: G[3], y: G[3], w: G[124], h: G[76] }
  MESSAGE_DELAY_FRAMES = 3.seconds
  MESSAGE_CHARACTER_INTERVAL = 0.05.seconds
  ENDING_MESSAGE_CHARACTER_INTERVAL = MESSAGE_CHARACTER_INTERVAL * 2
  FINAL_SACRIFICE_MESSAGE_CHARACTER_INTERVAL = ENDING_MESSAGE_CHARACTER_INTERVAL * 2
  FOOTSTEP_SOUND_PATH = "sounds/footstep.ogg"
  FOOTSTEP_INTERVAL_FRAMES = 0.45.seconds
  FOOTSTEP_GAIN = 0.9
  FOOTSTEP_PITCH_MIN = 0.85
  FOOTSTEP_PITCH_MAX = 1.1
  TYPING_SOUND_PATH = "sounds/typing.ogg"
  TYPING_GAIN = 0.2
  TYPING_PITCH_MIN = 0.95
  TYPING_PITCH_MAX = 1.05
  BUTTON_CLICK_GAIN = 0.5
  BUTTON_CLICK_PITCH_MIN = 1.45
  BUTTON_CLICK_PITCH_MAX = 1.7
  SCRAMBLE_SOUND_PATH = "sounds/scramble.ogg"
  SCRAMBLE_GAIN = 1.0
  NOTIFICATION_SOUND_PATH = "sounds/notification.ogg"
  NOTIFICATION_GAIN = 0.1
  ALTAR_CRASHING_SOUND_PATH = "sounds/altar_crashing.ogg"
  ALTAR_CRASHING_GAIN = 50.0
  WORD_EVENT_SOUND_GAIN = 1.0
  LAMP_WORD_EVENT_SOUND_GAIN = 5.0
  LEARNED_WORD_SOUND_PATHS = {
    "BELL" => "sounds/bell_use.ogg",
    "KEY" => "sounds/gate_open.ogg",
    "MIRROR" => "sounds/mirror_learned.ogg",
    "LAMP" => "sounds/lamp_learned.ogg"
  }
  SACRIFICED_WORD_SOUND_PATHS = {
    "BELL" => "sounds/bell_sacrificed.ogg",
    "KEY" => "sounds/gate_close.ogg",
    "MIRROR" => "sounds/mirror_sacrificed.ogg",
    "LAMP" => "sounds/lamp_sacrifice.ogg"
  }
  NAMELESS_SOUND_PATHS = [
    "sounds/nameless_1.ogg",
    "sounds/nameless_2.ogg",
    "sounds/nameless_3.ogg",
    "sounds/nameless_4.ogg"
  ]
  NAMELESS_PATROL_SOUND_PATH = "sounds/nameless_patrol.ogg"
  NAMELESS_GAIN = 1.0
  NAMELESS_PITCH = 1.0
  NAMELESS_PITCH_SPREAD = 0.2
  NAMELESS_SACRIFICED_BELL_PITCH = 1.75
  ENDING_ESCAPED_MUSIC_KEY = :bg_escaped
  ENDING_ESCAPED_MUSIC_PATH = "sounds/bg_escaped.ogg"
  ENDING_ESCAPED_MUSIC_GAIN = 0.5
  ENDING_ESCAPED_MUSIC_FADE_FRAMES = 8.seconds
  ALTAR_REINFORCEMENT_TEXT = "The altar does not want blood. It wants a name."
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
  RESET_HINTS = [
    "A name left behind changes the shape of the maze...",
    "A name left at the altar dissociates that item from reality...",
    "Every offering opens something while closing one's mind off from something else...",
    "Forgetting is not failure. It is information...",
    "Something ancient and nameless hunts those trapped here...",
    "Without the mirror, only fragments of the safe path remain...",
    "Without the bell, they gain speed and numbers...",
    "Without the key, that which hunts you freely roams the inner chambers...",
  ]
  RESET_FADE_OUT_FRAMES = 0.3.seconds
  RESET_HINT_FADE_FRAMES = 0.35.seconds
  RESET_HINT_HOLD_FRAMES = 2.seconds
  RESET_FADE_IN_FRAMES = 0.35.seconds
  ARCHIVE_PATH_RESET_FADE_FRAMES = 0.2.seconds
  ARCHIVE_OFF_PATH_WARNING_FRAMES = 0.25.seconds
  ARCHIVE_OFF_PATH_WARNING_TEXT = ""
  ALTAR_PANEL = { x: 430, y: 190, w: 420, h: 330 }
  ALTAR_WORD_ROW_H = 42
  ROOM_FADE_OUT_FRAMES = 8
  ROOM_FADE_IN_FRAMES = 8
  INTERACTION_RADIUS = S.value(128)
  POINTER_DRAG_DEADZONE = S.value(16)
  POINTER_TAP_MAX_FRAMES = 0.25.seconds
  ARCHIVE_SAFE_PATH_TOLERANCE = S.value(18)
  ARCHIVE_SAFE_PATH_EXTRA_WIDTH = S.value(56)
  BELL_COOLDOWN_FRAMES = 3.seconds
  BELL_STUN_FRAMES = 1.seconds
  BELL_FAILED_PULSE_FRAMES = 0.1.seconds
  LEARNED_LAMP_EFFECT_IN_FRAMES = 0.12.seconds
  LEARNED_LAMP_EFFECT_SETTLE_FRAMES = 0.9.seconds
  LEARNED_LAMP_EFFECT_FRAMES = LEARNED_LAMP_EFFECT_IN_FRAMES + LEARNED_LAMP_EFFECT_SETTLE_FRAMES
  LEARNED_LAMP_LIGHT_SIZE = 2048
  LEARNED_LAMP_PEAK_LIGHT_SIZE = 5000
  SACRIFICED_LAMP_LIGHT_SIZE = 1096
  SACRIFICED_LAMP_EFFECT_FRAMES = 0.5.seconds
  SACRIFICE_LAMP_GUTTER_FRAMES = 0.6.seconds
  SACRIFICE_KEY_SLAM_FRAMES = 0.35.seconds
  SACRIFICE_MIRROR_FLICKER_FRAMES = 0.7.seconds
  SACRIFICE_BELL_MONSTER_FLARE_FRAMES = 0.5.seconds
  LEARNED_KEY_EFFECT_FRAMES = 1.0.seconds
  LEARNED_MIRROR_EFFECT_IN_FRAMES = 0.1.seconds
  LEARNED_MIRROR_EFFECT_SETTLE_FRAMES = 1.0.seconds
  MIRROR_SAFE_PATH_SURGE_GLOW_SIZE = 92
  MIRROR_SAFE_PATH_SURGE_GLINT_SIZE = 18
  MIRROR_SACRIFICE_CELL_BUCKET_SIZE = 2
  BELL_RING_PULSE_FRAMES = 1.0.seconds
  BELL_TOOLTIP_TEXT = "Press E or click empty space to ring the bell and stun the Nameless Thing."
  MECHANIC_FEEDBACK_FRAMES = BELL_COOLDOWN_FRAMES + 2.0.seconds
  MECHANIC_FEEDBACK_FADE_FRAMES = 0.35.seconds
  MECHANIC_FEEDBACK_SKIP_HOLD_FRAMES = 0.75.seconds
  MECHANIC_FEEDBACK_SKIP_PROGRESS_LERP = 0.25
  SPAWN_HINT_FADE_FRAMES = 0.35.seconds
  SPAWN_HINT_HOLD_FRAMES = 5.seconds
  SPAWN_HINT_TOTAL_FRAMES = SPAWN_HINT_FADE_FRAMES * 2 + SPAWN_HINT_HOLD_FRAMES
  LEARNED_WORD_MESSAGES = {
    "BELL" => BELL_TOOLTIP_TEXT,
    "KEY" => "You hear the clanging of metal gates opening nearby.",
    "MIRROR" => "A series of paths reflect along the ground in the mirror, guiding you safely through the void.",
    "LAMP" => "The dark is thrust away from you, illuminating the space."
  }
  SACRIFICE_CONSEQUENCE_MESSAGES = {
    "BELL" => "The silence is deafening. Nothing can stop what hunts you in the maze.",
    "KEY" => "Gates forget what their locks were for... Something else remembers the openings to the sanctum...",
    "MIRROR" => "A chill runs down your spine. The reflected path fades from memory.",
    "LAMP" => "You shudder as darkness invades the space."
  }
  LOCKED_GATE_SPRITE_PATH = "sprites/locked_gate.png"
  FINAL_LOCKED_GATE_SPRITE_PATH = "sprites/locked_gate_final.png"
  LOCKED_GATE_FRAME_COUNT = 9
  LOCKED_GATE_FRAME_COLUMNS = 3
  LOCKED_GATE_FRAME_W = 512
  LOCKED_GATE_FRAME_H = 768
  FINAL_LOCKED_GATE_FRAME_W = 512
  FINAL_LOCKED_GATE_FRAME_H = 1280
  LOCKED_GATE_FRAME_HOLD = 5
  MONSTER_FINAL_FADE_FRAMES = 1.seconds
  BELL_SACRIFICE_SPEED_MULTIPLIER = 1.15
  SANCTUM_REGULAR_ALTAR_IDS = [:sanctum_key_altar, :sanctum_memory_altar]
  SANCTUM_FINAL_ALTAR_ID = :sanctum_name_altar
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
  attr_reader :player, :camera, :learned_words, :sacrificed_words, :sacrificed_object_ids, :current_room_id, :enemy, :enemies

  def initialize
    @player_name = PLAYER_NAME_WORD
    @level_data = LevelData.load_or_create
    restart
  end

  def restart
    @rooms = build_rooms
    @current_room_id = :hall
    room = current_room
    spawn = room.spawn(:default)
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @player = Player.new(spawn[:x], spawn[:y])
    @spawn_hint_started_at = nil
    @enemies = initial_enemies
    @enemy = @enemies.first
    @enemy_patrol_sound_pending = []
    @learned_words = []
    @learned_object_ids = []
    @learned_word_sources = {}
    @sacrificed_words = []
    @sacrificed_object_ids = []
    @forgotten_word_corruptors = {}
    @altar_open = false
    @active_altar = nil
    @altar_reinforcement_shown = false
    @room_transition = nil
    @reset_sequence = nil
    @archive_reset_spawn_id = :from_hall
    @camera.snap_to(@player)
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_slow_text = false
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
    @interaction_scramble_sound_played = false
    @interaction_visible_character_count = 0
    @mechanic_feedback_text = nil
    @mechanic_feedback_started_at = nil
    @mechanic_feedback_until = nil
    @mechanic_feedback_freeze_started_at = nil
    @mechanic_feedback_frozen_world_tick = nil
    @mechanic_feedback_skip_progress = 0
    @mechanic_feedback_skip_hold_started_at = nil
    @mechanic_feedback_skip_hold_start_progress = 0
    @world_paused_frames = 0
    @post_mechanic_feedback_sfx = []
    @pointer_gesture = nil
    @touch_gestures = {}
    @touch_movement_id = nil
    @pointer_taps = []
    @pointer_tap = nil
    @pointer_drag_vector = nil
    @env_tile_cache = {}
    @archive_safe_path_cells = nil
    @sacrificed_mirror_safe_path_cells = nil
    @sacrificed_mirror_retained_cell_lookup = nil
    @sacrificed_mirror_removed_cell_cutoffs = nil
    @archive_off_path_started_at = nil
    @key_gate_states = {}
    reset_key_gate_states
    @bell_last_used_at = nil
    @bell_failed_pulse_until = nil
    @learned_word_effects = {}
    @sacrifice_effects = {}
    @player_light_size_effect = nil
    @bell_ring_pulses = []
    @last_footstep_at = nil
    @footstep_audio_index = 0
    @typing_audio_index = 0
    @button_click_audio_index = 0
    @scramble_audio_index = 0
    @notification_audio_index = 0
    @altar_crashing_audio_index = 0
    @word_event_audio_index = 0
    @nameless_audio_index = 0
    @ending_monsters_fade_started_at = nil
    @ending_sequence_triggered = false
    @ending_phase = nil
    @ending_phase_started_at = nil
    @ending_player_start = nil
    @ending_player_target = nil
    @ending_title_corruptor = nil
    @ending_title_started_at = nil
    @ending_title_scramble_sound_played = false
    @ending_final_text_visible_character_count = 0
    @ending_escaped_music_started_at = nil
    @final_sacrifice_music_stopped = false
  end

  def mechanic_feedback_active?
    return false unless @mechanic_feedback_text && @mechanic_feedback_started_at && @mechanic_feedback_until
    return true if Kernel.tick_count < @mechanic_feedback_until

    finish_mechanic_feedback_freeze
    @mechanic_feedback_text = nil
    @mechanic_feedback_started_at = nil
    @mechanic_feedback_until = nil
    false
  end

  def start_spawn_hints
    @spawn_hint_started_at = Kernel.tick_count
  end

  def mechanic_feedback_freeze_active?
    mechanic_feedback_active? && !!@mechanic_feedback_freeze_started_at
  end

  def world_tick_count
    return @mechanic_feedback_frozen_world_tick if mechanic_feedback_freeze_active? && @mechanic_feedback_frozen_world_tick

    Kernel.tick_count - (@world_paused_frames || 0)
  end

  def finish_mechanic_feedback_freeze
    if @mechanic_feedback_freeze_started_at
      @world_paused_frames ||= 0
      @world_paused_frames += Kernel.tick_count - @mechanic_feedback_freeze_started_at
    end
    @mechanic_feedback_freeze_started_at = nil
    @mechanic_feedback_frozen_world_tick = nil
  end

  def interaction_tick_count
    ending_sequence_triggered? ? Kernel.tick_count : world_tick_count
  end

  def build_rooms
    rooms = {}
    (@level_data["rooms"] || {}).each do |room_id, room_data|
      room_key = room_id.to_sym
      world = room_data["world"] || {}
      world_w = tile_value(world["cols"] || WORLD_W / MAP_TILE)
      world_h = tile_value(world["rows"] || WORLD_H / MAP_TILE)
      play_area = grid_rect(room_data["play_area"] || LevelData.rect(3, 3, 124, 76))
      interactables = (room_data["objects"] || []).map { |record| build_interactable(record) }.compact
      barriers = (room_data["barriers"] || []).map { |record| grid_rect(record) }
      safe_paths = (room_data["safe_paths"] || []).map { |record| grid_rect(record) }
      locked_gates = (room_data["locked_gates"] || []).map { |record| locked_gate_record(record) }
      spawns = default_player_spawns(room_key, world_w, world_h)
      add_exit_return_spawns(spawns, room_data["objects"] || [])

      rooms[room_key] = Room.new(
        room_key,
        world_w,
        world_h,
        play_area,
        spawns,
        interactables,
        barriers,
        safe_paths: safe_paths,
        locked_gates: locked_gates
      )
    end
    rooms
  end

  def tile_value value
    value.to_i * MAP_TILE
  end

  def grid_center record
    { x: tile_value(record["col"]), y: tile_value(record["row"]) }
  end

  def grid_rect record
    {
      x: tile_value(record["col"]),
      y: tile_value(record["row"]),
      w: tile_value(record["w_cols"]),
      h: tile_value(record["h_rows"])
    }
  end

  def centered_rect record, w, h
    center = grid_center(record)
    { x: center[:x] - w / 2, y: center[:y] - h / 2, w: w, h: h }
  end

  def build_interactable record
    id = symbol_or_nil(record["id"])
    case record["type"]
    when "bell"
      rect = centered_rect(record, Bell::W, Bell::H)
      Bell.new(rect[:x], rect[:y], id)
    when "lamp"
      rect = centered_rect(record, Lamp::SIZE, Lamp::SIZE)
      Lamp.new(rect[:x], rect[:y], id)
    when "altar"
      rect = centered_rect(record, Altar::W, Altar::H)
      Altar.new(rect[:x], rect[:y], id)
    when "name_altar"
      rect = centered_rect(record, Altar::W, Altar::H)
      NameAltar.new(rect[:x], rect[:y], id || SANCTUM_FINAL_ALTAR_ID)
    when "mirror"
      rect = centered_rect(record, Mirror::W, Mirror::H)
      Mirror.new(rect[:x], rect[:y], id)
    when "archive_key"
      rect = centered_rect(record, ArchiveKey::W, ArchiveKey::H)
      ArchiveKey.new(rect[:x], rect[:y], id)
    when "final_door"
      rect = centered_rect(record, FinalDoor::W, FinalDoor::H)
      FinalDoor.new(rect[:x], rect[:y], id)
    when "exit"
      rect = centered_rect(record, Exit::W, Exit::H)
      options = {}
      options[:unlock_altar_id] = symbol_or_nil(record["unlock_altar_id"]) if record["unlock_altar_id"]
      Exit.new(
        rect[:x],
        rect[:y],
        id,
        symbol_or_nil(record["target_room"]),
        symbol_or_nil(record["target_spawn"]),
        options
      )
    else
      nil
    end
  end

  def locked_gate_record record
    {
      id: symbol_or_nil(record["id"]),
      rect: grid_rect(record["rect"]),
      sprite_rect: grid_rect(record["sprite_rect"] || record["rect"]),
      path: record["path"],
      frame_w: record["frame_w"].to_i,
      frame_h: record["frame_h"].to_i
    }
  end

  def default_player_spawns room_id, world_w, world_h
    default_x = room_id == :hall ? world_w / 2 : G[14]
    {
      default: {
        x: default_x - Player::SIZE / 2,
        y: world_h / 2 - Player::SIZE / 2
      }
    }
  end

  def add_exit_return_spawns spawns, object_records
    object_records.each do |record|
      next unless record["type"] == "exit"
      next unless record["return_spawn_id"]

      spawn_id = symbol_or_nil(record["return_spawn_id"])
      spawn_col = record["col"].to_i + record["spawn_offset_cols"].to_i
      spawn_row = record["row"].to_i + record["spawn_offset_rows"].to_i
      spawns[spawn_id] = {
        x: tile_value(spawn_col) - Player::SIZE / 2,
        y: tile_value(spawn_row) - Player::SIZE / 2
      }
    end
  end

  def symbol_or_nil value
    return nil if value.nil?

    value.to_sym
  end

  def initial_enemies
    spawn = enemy_spawn_record("archive_primary")
    return [] unless spawn

    [enemy_from_spawn_record(spawn)]
  end

  def enemy_from_spawn_record spawn
    runtime_id = symbol_or_nil(spawn["runtime_id"])
    NamelessThing.new(
      symbol_or_nil(spawn["room"]),
      tile_value(spawn["col"]) - NamelessThing::SIZE / 2,
      tile_value(spawn["row"]) - NamelessThing::SIZE / 2,
      runtime_id
    )
  end

  def enemy_spawn_record id
    (@level_data["enemy_spawns"] || []).find { |spawn| spawn["id"] == id }
  end

  def enemy_spawn id
    spawn = enemy_spawn_record(id)
    return { x: WORLD_W / 2 - NamelessThing::SIZE / 2, y: WORLD_H / 2 - NamelessThing::SIZE / 2 } unless spawn

    {
      x: tile_value(spawn["col"]) - NamelessThing::SIZE / 2,
      y: tile_value(spawn["row"]) - NamelessThing::SIZE / 2
    }
  end

  def reload_rooms_from_level_data preserve_player: true
    previous_room_id = @current_room_id
    player_position = @player ? { x: @player.x, y: @player.y } : nil
    @rooms = build_rooms
    @current_room_id = previous_room_id if @rooms[previous_room_id]
    if preserve_player && @player && player_position
      @player.x = player_position[:x]
      @player.y = player_position[:y]
    end
    @env_tile_cache = {}
    @archive_safe_path_cells = nil
    @sacrificed_mirror_safe_path_cells = nil
  end

  def current_room
    @rooms[@current_room_id]
  end

  def interactables
    current_room.interactables
  end

end
