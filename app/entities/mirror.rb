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

  def sacrifice!
    return if sacrificed?

    super
    @sacrificed_at = Kernel.tick_count
  end

  def interaction_text
    "A cold reflection shows paths the floor refuses to keep."
  end

  def sacrificed_interaction_text
    "The frame holds only dust-dark glass."
  end

  def render args, outputs = args.outputs, camera = nil
    mirror_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << mirror_sprite(mirror_rect)
  end

  def mirror_sprite mirror_rect
    frame_index = sacrificed_frame_index

    mirror_rect.merge(
      path: SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    )
  end

  def sacrificed_frame_index
    return 0 unless sacrificed?

    @sacrificed_at.frame_index(
      count: FRAME_COUNT,
      hold_for: FRAME_HOLD,
      loop: false
    ) || FRAME_COUNT - 1
  end
end
