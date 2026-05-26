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

  def update args
    target_dx = 0
    target_dy = 0
    target_dx -= SPEED if args.inputs.keyboard.left || args.inputs.keyboard.a
    target_dx += SPEED if args.inputs.keyboard.right || args.inputs.keyboard.d
    target_dy += SPEED if args.inputs.keyboard.up || args.inputs.keyboard.w
    target_dy -= SPEED if args.inputs.keyboard.down || args.inputs.keyboard.s

    @dx = @dx.lerp(target_dx, ACCELERATION)
    @dy = @dy.lerp(target_dy, ACCELERATION)

    @x = (@x + @dx).clamp(52, Grid.w - 52 - @w)
    @y = (@y + @dy).clamp(58, Grid.h - 58 - @h)
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def render args, outputs = args.outputs
    outputs.sprites << rect.merge(path: "sprites/t-pose/white.png", **Render.color(:player))
  end

  def render_light args, outputs = args.outputs
    outputs.sprites << center.merge(
      path: "sprites/mask.png",
      w: LIGHT_SIZE,
      h: LIGHT_SIZE,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end
end
