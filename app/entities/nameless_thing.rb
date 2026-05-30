class NamelessThing
  SIZE = WorldScale.value(88)
  PATROL_SPRITE_PATH = "sprites/monster.png"
  CHASE_SPRITE_PATH = "sprites/monster_aggro.png"
  FRAME_COUNT = 8
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  PATROL_FRAME_HOLD = 9
  CHASE_FRAME_HOLD = 5
  LIGHT_SIZE = 256
  LIGHT_FADE_FRAMES = Render::TRANSITION_FRAMES
  PATROL_SPEED = 1.45 * WorldScale::FACTOR
  CHASE_SPEED = 2.15 * WorldScale::FACTOR
  BELL_SACRIFICED_CHASE_SPEED = 3.05 * WorldScale::FACTOR
  CHASE_RADIUS = WorldScale.value(350)
  PATROL_TARGET_DISTANCE = WorldScale.value(18)

  attr_accessor :x, :y, :room_id
  attr_reader :w, :h, :state

  def initialize room_id, x, y
    @room_id = room_id
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @state = :patrol
    @patrol_index = 0
    @stunned_until = 0
    @animation_started_at = Kernel.tick_count
    @light_fade_started_at = nil
    @light_fade_direction = nil
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def update args, player, room, patrol_points, bell_sacrificed = false
    if stunned?
      @state = :stunned
      return nil
    end

    set_state(close_to_player?(player) ? :chase : :patrol)

    target = @state == :chase ? player.center : current_patrol_point(patrol_points)
    move_toward(target, @state == :chase ? chase_speed(bell_sacrificed) : PATROL_SPEED, room.play_area)
    advance_patrol(patrol_points) if @state == :patrol
  end

  def reset! room_id, spawn
    @room_id = room_id
    @x = spawn[:x]
    @y = spawn[:y]
    @state = :patrol
    @patrol_index = 0
    @stunned_until = 0
    @animation_started_at = Kernel.tick_count
    @light_fade_started_at = nil
    @light_fade_direction = nil
  end

  def stun! duration_frames
    @stunned_until = [@stunned_until, Kernel.tick_count + duration_frames].max
  end

  def clear_stun!
    @stunned_until = 0
  end

  def stunned?
    Kernel.tick_count < @stunned_until
  end

  def chase_speed bell_sacrificed
    bell_sacrificed ? BELL_SACRIFICED_CHASE_SPEED : CHASE_SPEED
  end

  def render args, outputs = args.outputs, camera = nil
    enemy_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << enemy_rect.merge(enemy_sprite)
  end

  def set_state next_state
    return if @state == next_state

    if @state == :patrol && next_state == :chase
      @light_fade_started_at = Kernel.tick_count
      @light_fade_direction = :in
    elsif @state == :chase && next_state == :patrol
      @light_fade_started_at = Kernel.tick_count
      @light_fade_direction = :out
    end
    @state = next_state
    @animation_started_at = Kernel.tick_count
  end

  def enemy_sprite
    chasing = @state == :chase
    frame_hold = chasing ? CHASE_FRAME_HOLD : PATROL_FRAME_HOLD
    frame_index = @animation_started_at.frame_index(
      count: FRAME_COUNT,
      hold_for: frame_hold,
      repeat: true
    ) || 0

    {
      path: chasing ? CHASE_SPRITE_PATH : PATROL_SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    }
  end

  def render_light args, outputs = args.outputs, camera = nil
    alpha = light_alpha
    return if alpha <= 0

    light_center = camera ? camera.screen_point(center) : center
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: LIGHT_SIZE,
      h: LIGHT_SIZE,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 255,
      g: 0,
      b: 0,
      a: alpha,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def light_alpha
    return 255 if @state == :chase && @light_fade_direction != :in
    return 0 unless @light_fade_started_at

    elapsed = Kernel.tick_count - @light_fade_started_at
    progress = (elapsed * 255 / LIGHT_FADE_FRAMES).clamp(0, 255)
    @light_fade_direction == :in ? progress : 255 - progress
  end

  def close_to_player? player
    distance_between(center, player.center) <= CHASE_RADIUS
  end

  def current_patrol_point patrol_points
    patrol_points[@patrol_index % patrol_points.length]
  end

  def advance_patrol patrol_points
    return if distance_between(center, current_patrol_point(patrol_points)) > PATROL_TARGET_DISTANCE

    @patrol_index = (@patrol_index + 1) % patrol_points.length
  end

  def move_toward target, speed, bounds
    from = center
    distance = distance_between(from, target)
    return if distance <= 0.001

    @x += (target[:x] - from[:x]) / distance * speed
    @y += (target[:y] - from[:y]) / distance * speed
    clamp_to(bounds)
  end

  def clamp_to bounds
    @x = @x.clamp(bounds[:x], bounds[:x] + bounds[:w] - @w)
    @y = @y.clamp(bounds[:y], bounds[:y] + bounds[:h] - @h)
  end

  def distance_between first, second
    dx = second[:x] - first[:x]
    dy = second[:y] - first[:y]
    Math.sqrt(dx * dx + dy * dy)
  end

  def rects_intersect? first, second
    first[:x] < second[:x] + second[:w] &&
      first[:x] + first[:w] > second[:x] &&
      first[:y] < second[:y] + second[:h] &&
      first[:y] + first[:h] > second[:y]
  end
end
