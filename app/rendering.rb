module Render
  TRANSITION_FRAMES = 28
  HOLE_PUNCH_BLENDMODE = Numeric.compose_blendmode(
    BLENDFACTOR_ZERO,
    BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    BLENDOPERATION_ADD,
    BLENDFACTOR_ZERO,
    BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    BLENDOPERATION_ADD
  )

  PALETTE = {
    void: { r: 10, g: 9, b: 14 },
    stone: { r: 48, g: 49, b: 58 },
    wall: { r: 26, g: 26, b: 34 },
    ash: { r: 170, g: 170, b: 165 },
    ember: { r: 210, g: 92, b: 54 },
    player: { r: 220, g: 218, b: 205 }
  }

  def self.rect x, y, w, h
    { x: x, y: y, w: w, h: h }
  end

  def self.color name
    PALETTE[name]
  end

  def self.solid rect, color_name, overrides = {}
    rect.merge(path: :solid, **PALETTE[color_name], **overrides)
  end

  def self.label x, y, text, color_name = :ash, overrides = {}
    { x: x, y: y, text: text, **PALETTE[color_name], **overrides}
  end

  def self.fullscreen color_name = :void, overrides = {}
    solid({ x: 0, y: 0, w: Grid.w, h: Grid.h}, color_name, overrides)
  end
end
