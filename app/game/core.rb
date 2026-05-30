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
  MECHANIC_FEEDBACK_FRAMES = BELL_STUN_FRAMES
  LEARNED_WORD_MESSAGES = {
    "BELL" => BELL_TOOLTIP_TEXT,
    "KEY" => "You hear the clanging of metal gates opening nearby.",
    "MIRROR" => "A series of paths reflect along the ground in the mirror, guiding you safely through the void.",
    "LAMP" => "The dark is thrust away from you, illuminating the space."
  }
  SACRIFICE_CONSEQUENCE_MESSAGES = {
    "BELL" => "The silence is deafening. Nothing can stop what hunts you.",
    "KEY" => "The metal gates forgets what their locks were for, slamming shut.",
    "MIRROR" => "The reflected path fades from memory.",
    "LAMP" => "The dark invades the space."
  }
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
    @altar_reinforcement_shown = false
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
    @mechanic_feedback_text = nil
    @mechanic_feedback_until = nil
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

end
