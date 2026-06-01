class ArchiveKey < Interactable
  SPRITE_PATH = "sprites/key.png"
  SPRITE_W = 512
  SPRITE_H = 1025
  H = WorldScale.value(24)
  W = ((H * SPRITE_W / SPRITE_H).round)

  def initialize x, y, id
    super(x, y, W, H, id: id, word: "KEY")
  end

  def interaction_text
    "A small iron key lies where the path ends."
  end

  def sacrificed_interaction_text
    "The shape is gone; only the need for it remains."
  end

  def render args, outputs = args.outputs, camera = nil, tick = Kernel.tick_count
    key_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << key_rect.merge(
      path: SPRITE_PATH,
      tile_x: 0,
      tile_y: 0,
      tile_w: SPRITE_W,
      tile_h: SPRITE_H,
      a: sacrificed? ? 95 : 255
    )
  end
end
