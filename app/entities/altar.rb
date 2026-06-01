class Altar < Interactable
  W = 512
  H = 512
  SPRITE_PATH = "sprites/altar.png"
  BREAK_SPRITE_PATH = "sprites/altar_break_9.png"
  BREAK_FRAME_COUNT = 9
  BREAK_FRAME_COLUMNS = 3
  BREAK_FRAME_SIZE = 1024
  BREAK_FRAME_HOLD = 5

  def initialize x, y, id
    super(x, y, W, H, id: id)
    @sacrificed_at = nil
  end

  def sacrifice! tick = Kernel.tick_count
    return if sacrificed?

    super
    @sacrificed_at = tick
  end

  def interact game, args = nil
    return "The altar is spent." if sacrificed?

    game.open_altar(self)
  end

  def interaction_text
    return "The altar is spent." if sacrificed?

    "The altar waits for a name."
  end

  def render args, outputs = args.outputs, camera = nil, tick = Kernel.tick_count
    altar_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << altar_sprite(altar_rect, tick)
  end

  def altar_sprite altar_rect, tick = Kernel.tick_count
    return altar_rect.merge(path: SPRITE_PATH) unless sacrificed?

    frame_index = (tick - @sacrificed_at).idiv(BREAK_FRAME_HOLD).clamp(0, BREAK_FRAME_COUNT - 1)

    altar_rect.merge(
      path: BREAK_SPRITE_PATH,
      tile_x: frame_index % BREAK_FRAME_COLUMNS * BREAK_FRAME_SIZE,
      tile_y: frame_index.idiv(BREAK_FRAME_COLUMNS) * BREAK_FRAME_SIZE,
      tile_w: BREAK_FRAME_SIZE,
      tile_h: BREAK_FRAME_SIZE
    )
  end
end
