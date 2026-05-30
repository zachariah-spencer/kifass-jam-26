class Bell < Interactable
  SPRITE_PATH = "sprites/bell.png"
  SPRITE_SIZE = 1024
  W = 256
  H = 256

  def initialize x, y, id
    super(x, y, W, H, id: id, word: "BELL")
  end

  def interaction_text
    "A row of tarnished bells hangs in the sealed alcove."
  end

  def sacrificed_interaction_text
    "The silent hooks remember a weight they cannot name."
  end

  def render args, outputs = args.outputs, camera = nil
    bell_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << bell_rect.merge(
      path: SPRITE_PATH,
      tile_x: 0,
      tile_y: 0,
      tile_w: SPRITE_SIZE,
      tile_h: SPRITE_SIZE,
      a: sacrificed? ? 95 : 255
    )
  end
end
