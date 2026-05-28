module WorldScale
  ORIGINAL_PLAYER_SIZE = 34.0
  CURRENT_PLAYER_SIZE = 256.0
  FACTOR = CURRENT_PLAYER_SIZE / ORIGINAL_PLAYER_SIZE

  def self.value amount
    (amount * FACTOR).round
  end

  def self.rect rect
    rect.transform_values { |value| value.is_a?(Numeric) ? WorldScale.value(value) : value }
  end
end

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
    stone: { r: 39, g: 22, b: 10 },
    wall: { r: 26, g: 26, b: 34 },
    ash: { r: 170, g: 170, b: 165 },
    ember: { r: 210, g: 92, b: 54 },
    brass: { r: 154, g: 121, b: 74 },
    flame: { r: 255, g: 188, b: 86 },
    altar: { r: 82, g: 64, b: 70 },
    player: { r: 220, g: 218, b: 205 },
    enemy: { r: 16, g: 14, b: 19 }
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
