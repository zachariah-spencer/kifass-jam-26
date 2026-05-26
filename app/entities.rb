class Interactable
  attr_accessor :x, :y
  attr_reader :w, :h

  def initialize x, y, w, h
    @x = x
    @y = y
    @w = w
    @h = h
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def contains_point? point
    point_x = point.is_a?(Hash) ? point[:x] : point.x
    point_y = point.is_a?(Hash) ? point[:y] : point.y
    point_x >= @x && point_x <= @x + @w && point_y >= @y && point_y <= @y + @h
  end

  def interaction_text
    nil
  end

  def update args
  end

  def render args, outputs = args.outputs, camera = nil
  end

  def render_light args, outputs = args.outputs, camera = nil
  end
end

class Lamp < Interactable
  SIZE = 28
  LIGHT_SIZE = 420

  def initialize x, y
    super(x, y, SIZE, SIZE)
  end

  def interaction_text
    "Dim firelight shines through the glass."
  end

  def render args, outputs = args.outputs, camera = nil
    lamp_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << lamp_rect.merge(path: "sprites/circle/yellow.png", **Render.color(:brass))
    outputs.sprites << {
      x: lamp_rect[:x] + 8,
      y: lamp_rect[:y] + 8,
      w: 12,
      h: 12,
      path: "sprites/circle/yellow.png",
      **Render.color(:flame)
    }
  end

  def render_light args, outputs = args.outputs, camera = nil
    light_center = camera ? camera.screen_point(center) : center
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: LIGHT_SIZE,
      h: LIGHT_SIZE,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end
end

class Player
  SIZE = 34
  SPEED = 4.5
  ACCELERATION = 0.4
  LIGHT_SIZE = 1024

  attr_accessor :x, :y
  attr_reader :w, :h

  def initialize x, y
    @x = x
    @y = y
    @dx = 0
    @dy = 0
    @w = SIZE
    @h = SIZE
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def update args, bounds = nil
    target_dx = 0
    target_dy = 0
    target_dx -= SPEED if args.inputs.keyboard.left || args.inputs.keyboard.a
    target_dx += SPEED if args.inputs.keyboard.right || args.inputs.keyboard.d
    target_dy += SPEED if args.inputs.keyboard.up || args.inputs.keyboard.w
    target_dy -= SPEED if args.inputs.keyboard.down || args.inputs.keyboard.s

    @dx = @dx.lerp(target_dx, ACCELERATION)
    @dy = @dy.lerp(target_dy, ACCELERATION)

    bounds ||= { x: 52, y: 58, w: Grid.w - 104, h: Grid.h - 116 }
    @x = (@x + @dx).clamp(bounds[:x], bounds[:x] + bounds[:w] - @w)
    @y = (@y + @dy).clamp(bounds[:y], bounds[:y] + bounds[:h] - @h)
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def render args, outputs = args.outputs, camera = nil
    player_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << player_rect.merge(path: "sprites/t-pose/white.png", **Render.color(:player))
  end

  def render_light args, outputs = args.outputs, camera = nil
    light_center = camera ? camera.screen_point(center) : center
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: LIGHT_SIZE,
      h: LIGHT_SIZE,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end
end
