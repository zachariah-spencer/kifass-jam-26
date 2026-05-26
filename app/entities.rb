class Player
  SIZE = 34
  SPEED = 4.5
  ACCELERATION = 0.4

  attr_accessor :x, :y
  attr_reader :w, :h

  def initialize x, y
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def update args
    dx = 0
    dy = 0
    dx -= SPEED if args.inputs.keyboard.left || args.inputs.keyboard.a
    dx += SPEED if args.inputs.keyboard.right || args.inputs.keyboard.d
    dy += SPEED if args.inputs.keyboard.up || args.inputs.keyboard.w
    dy -= SPEED if args.inputs.keyboard.down || args.inputs.keyboard.s

    @x = (@x + dx).clamp(52, Grid.w - 52 - @w)
    @y = (@y + dy).clamp(58, Grid.h - 58 - @h)
  end

  def render args
    args.outputs.sprites << rect.merge(path: "sprites/t-pose/white.png", **Render.color(:player))
  end
end
