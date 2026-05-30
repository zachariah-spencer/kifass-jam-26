class Exit < Interactable
  W = WorldScale.value(92)
  H = WorldScale.value(92)
  SPRITE_PATH = "sprites/door.png"
  FRAME_COUNT = 8
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  FRAME_HOLD = 5

  attr_reader :target_room_id, :target_spawn_id, :unlock_altar_id

  def initialize x, y, id, target_room_id, target_spawn_id, options = nil
    unlock_altar_id = options && options[:unlock_altar_id]
    super(x, y, W, H, id: id)
    @target_room_id = target_room_id
    @target_spawn_id = target_spawn_id
    @unlock_altar_id = unlock_altar_id
    @locked = !!unlock_altar_id
    @unlocked_at = @locked ? nil : Kernel.tick_count
  end

  def interact game
    return "The passage is sealed. The altar waits for a name." unless can_traverse?

    game.request_room_transition(@target_room_id, @target_spawn_id, self)
  end

  def locked?
    @locked
  end

  def can_traverse?
    !locked?
  end

  def unlock!
    return unless @locked

    @locked = false
    @unlocked_at = Kernel.tick_count
  end

  def interaction_text
    return "The passage is sealed. The altar waits for a name." if locked?

    "The passage exhales cold air."
  end

  def render args, outputs = args.outputs, camera = nil
    exit_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << exit_sprite(exit_rect)
  end

  def exit_sprite exit_rect
    frame_index = exit_frame_index

    exit_rect.merge(
      path: SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    )
  end

  def exit_frame_index
    return 0 unless @unlocked_at

    @unlocked_at.frame_index(
      count: FRAME_COUNT,
      hold_for: FRAME_HOLD,
      loop: false
    ) || FRAME_COUNT - 1
  end
end
