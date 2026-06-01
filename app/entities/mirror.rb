class Mirror < Interactable
  W = WorldScale.value(54)
  H = WorldScale.value(74)
  SPRITE_PATH = "sprites/mirror.png"
  FRAME_COUNT = 4
  FRAME_COLUMNS = 2
  FRAME_SIZE = 1024
  FRAME_HOLD = 6

  def initialize x, y, id
    super(x, y, W, H, id: id, word: "MIRROR")
    @sacrificed_at = nil
  end

  def sacrifice! tick = Kernel.tick_count
    return if sacrificed?

    super
    @sacrificed_at = tick
  end

  def interaction_text
    "A cold reflection shows paths the floor refuses to keep."
  end

  def sacrificed_interaction_text
    "The frame holds only dust-dark glass."
  end

  def render args, outputs = args.outputs, camera = nil, tick = Kernel.tick_count
    mirror_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << mirror_sprite(mirror_rect, tick)
  end

  def mirror_sprite mirror_rect, tick = Kernel.tick_count
    frame_index = sacrificed_frame_index(tick)

    mirror_rect.merge(
      path: SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    )
  end

  def sacrificed_frame_index tick = Kernel.tick_count
    return 0 unless sacrificed?

    (tick - @sacrificed_at).idiv(FRAME_HOLD).clamp(0, FRAME_COUNT - 1)
  end
end
