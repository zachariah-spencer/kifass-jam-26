class Player
  SIZE = 256
  IDLE_SPRITE_PATH = "sprites/player_idle.png"
  IDLE_FRAME_COUNT = 16
  IDLE_FRAME_COLUMNS = 4
  IDLE_FRAME_SIZE = 1024
  IDLE_FRAME_HOLD = 5
  RUN_SPRITE_PATH = "sprites/player_run.png"
  RUN_FRAME_COUNT = 4
  RUN_FRAME_COLUMNS = 2
  RUN_FRAME_SIZE = 1024
  RUN_FRAME_HOLD = 10
  MOVING_EPSILON = 0.1
  SPEED = 4.5 * WorldScale::FACTOR
  ACCELERATION = 0.4
  LIGHT_OSCILLATION_AMOUNT = 36
  LIGHT_OSCILLATION_FRAMES = 90

  attr_accessor :x, :y, :light_size
  attr_reader :w, :h

  def initialize x, y
    @x = x
    @y = y
    @dx = 0
    @dy = 0
    @w = SIZE
    @h = SIZE
    @light_size = 1024
    @idle_started_at = Kernel.tick_count
    @run_started_at = Kernel.tick_count
    @animation_override = nil
    @facing_left = false
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def update args, bounds = nil, barriers = [], movement_vector = nil
    target_dx = 0
    target_dy = 0
    target_dx -= SPEED if args.inputs.keyboard.left || args.inputs.keyboard.a
    target_dx += SPEED if args.inputs.keyboard.right || args.inputs.keyboard.d
    target_dy += SPEED if args.inputs.keyboard.up || args.inputs.keyboard.w
    target_dy -= SPEED if args.inputs.keyboard.down || args.inputs.keyboard.s
    if movement_vector
      target_dx += movement_vector[:x] * SPEED
      target_dy += movement_vector[:y] * SPEED
    end

    @dx = @dx.lerp(target_dx, ACCELERATION)
    @dy = @dy.lerp(target_dy, ACCELERATION)
    @facing_left = @dx < -MOVING_EPSILON if @dx.abs > MOVING_EPSILON

    @x += @dx
    @x = @x.clamp(bounds[:x], bounds[:x] + bounds[:w] - @w) if bounds
    resolve_barrier_collisions(:x, barriers)
    @y += @dy
    @y = @y.clamp(bounds[:y], bounds[:y] + bounds[:h] - @h) if bounds
    resolve_barrier_collisions(:y, barriers)
  end

  def resolve_barrier_collisions axis, barriers
    barriers.each do |barrier|
      next unless rects_intersect?(rect, barrier)

      if axis == :x
        if @dx > 0
          @x = barrier[:x] - @w
        elsif @dx < 0
          @x = barrier[:x] + barrier[:w]
        end
        @dx = 0
      else
        if @dy > 0
          @y = barrier[:y] - @h
        elsif @dy < 0
          @y = barrier[:y] + barrier[:h]
        end
        @dy = 0
      end
    end
  end

  def rects_intersect? first, second
    first[:x] < second[:x] + second[:w] &&
      first[:x] + first[:w] > second[:x] &&
      first[:y] < second[:y] + second[:h] &&
      first[:y] + first[:h] > second[:y]
  end

  def stop!
    @dx = 0
    @dy = 0
  end

  def force_run_animation! tick = Kernel.tick_count
    @animation_override = :run
    @run_started_at = tick
  end

  def force_idle_animation! tick = Kernel.tick_count
    @animation_override = :idle
    @idle_started_at = tick
  end

  def clear_animation_override!
    @animation_override = nil
  end

  def face_toward_x target_x
    @facing_left = target_x < @x
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def render args, outputs = args.outputs, camera = nil, alpha = 255, tick = Kernel.tick_count
    player_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << player_rect.merge(player_sprite(tick)).merge(a: alpha)
  end

  def player_sprite tick = Kernel.tick_count
    running = @animation_override == :run || (!@animation_override && moving?)
    running ? animation_sprite(RUN_SPRITE_PATH, RUN_FRAME_COUNT, RUN_FRAME_COLUMNS, RUN_FRAME_SIZE, RUN_FRAME_HOLD, @run_started_at, tick) :
              animation_sprite(IDLE_SPRITE_PATH, IDLE_FRAME_COUNT, IDLE_FRAME_COLUMNS, IDLE_FRAME_SIZE, IDLE_FRAME_HOLD, @idle_started_at, tick)
  end

  def animation_sprite path, frame_count, frame_columns, frame_size, frame_hold, started_at, tick
    frame_index = ((tick - started_at).idiv(frame_hold) % frame_count).clamp(0, frame_count - 1)

    {
      path: path,
      tile_x: frame_index % frame_columns * frame_size,
      tile_y: frame_index.idiv(frame_columns) * frame_size,
      tile_w: frame_size,
      tile_h: frame_size,
      flip_horizontally: @facing_left
    }
  end

  def moving?
    @dx.abs > MOVING_EPSILON || @dy.abs > MOVING_EPSILON
  end

  def render_light args, outputs = args.outputs, camera = nil, light_multiplier = 1.0, tick = Kernel.tick_count
    light_center = camera ? camera.screen_point(center) : center
    light_size = oscillating_light_size(@light_size, LIGHT_OSCILLATION_AMOUNT, tick) * light_multiplier
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def oscillating_light_size base_size, amount, tick = Kernel.tick_count
    wave = Math.sin(tick * Math::PI * 2 / LIGHT_OSCILLATION_FRAMES)
    base_size + wave * amount
  end
end
