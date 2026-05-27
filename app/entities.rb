class Interactable
  LIGHT_OSCILLATION_FRAMES = 72

  attr_accessor :x, :y
  attr_reader :id, :w, :h, :word

  def initialize x, y, w, h, id: nil, word: nil
    @x = x
    @y = y
    @w = w
    @h = h
    @id = id
    @word = word
    @sacrificed = false
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

  def sacrificed_interaction_text
    interaction_text
  end

  def interact game
    game.interaction_text_for(self)
  end

  def sacrificed?
    @sacrificed
  end

  def sacrifice!
    @sacrificed = true
  end

  def update args
  end

  def render args, outputs = args.outputs, camera = nil
  end

  def render_light args, outputs = args.outputs, camera = nil
  end

  def oscillating_light_size base_size, amount, phase = 0
    wave = Math.sin((Kernel.tick_count + phase) * Math::PI * 2 / LIGHT_OSCILLATION_FRAMES)
    base_size + wave * amount
  end
end

class Lamp < Interactable
  SIZE = 28
  LIGHT_SIZE = 512
  LIGHT_OSCILLATION_AMOUNT = 28

  def initialize x, y, id
    super(x, y, SIZE, SIZE, id: id, word: "LAMP")
  end

  def interaction_text
    "Dim firelight shines through the glass."
  end

  def sacrificed_interaction_text
    "You find it hard to navigate the space but cannot recall why...."
  end

  def render args, outputs = args.outputs, camera = nil
    lamp_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << lamp_rect.merge(path: "sprites/circle/yellow.png", **Render.color(sacrificed? ? :ash : :brass))
    return if sacrificed?

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
    return if sacrificed?

    light_center = camera ? camera.screen_point(center) : center
    light_size = oscillating_light_size(LIGHT_SIZE, LIGHT_OSCILLATION_AMOUNT, @x + @y)
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end
end

class Altar < Interactable
  W = 92
  H = 58

  def initialize x, y, id
    super(x, y, W, H, id: id)
  end

  def interact game
    game.open_altar(self)
  end

  def interaction_text
    "The altar waits for a name."
  end

  def render args, outputs = args.outputs, camera = nil
    altar_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(altar_rect, :altar)
    outputs.borders << altar_rect.merge(**Render.color(:brass))
    outputs.sprites << Render.solid(
      {
        x: altar_rect[:x] + 14,
        y: altar_rect[:y] + altar_rect[:h] - 18,
        w: altar_rect[:w] - 28,
        h: 6
      },
      :ember
    )
  end
end

class Exit < Interactable
  W = 92
  H = 92

  attr_reader :target_room_id, :target_spawn_id

  def initialize x, y, id, target_room_id, target_spawn_id
    super(x, y, W, H, id: id)
    @target_room_id = target_room_id
    @target_spawn_id = target_spawn_id
  end

  def interact game
    game.request_room_transition(@target_room_id, @target_spawn_id, self)
  end

  def interaction_text
    "The passage exhales cold air."
  end

  def render args, outputs = args.outputs, camera = nil
    exit_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(exit_rect, :void, a: 210)
    outputs.borders << exit_rect.merge(**Render.color(:ember))
  end
end

class NamelessThing
  SIZE = 44
  PATROL_SPEED = 1.45
  CHASE_SPEED = 2.15
  CHASE_RADIUS = 420
  PATROL_TARGET_DISTANCE = 18
  EXIT_COOLDOWN_FRAMES = 45

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
    @exit_cooldown_until = 0
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def update args, player, room, exits, patrol_points
    @state = close_to_player?(player) ? :chase : :patrol

    target = @state == :chase ? player.center : current_patrol_point(patrol_points)
    move_toward(target, @state == :chase ? CHASE_SPEED : PATROL_SPEED, room.play_area)
    advance_patrol(patrol_points) if @state == :patrol

    return nil if Kernel.tick_count < @exit_cooldown_until

    exits.find { |exit| rects_intersect?(rect, exit.rect) }
  end

  def enter_room room_id, spawn, play_area
    @room_id = room_id
    @x = spawn[:x]
    @y = spawn[:y]
    clamp_to(play_area)
    @patrol_index = 0
    @exit_cooldown_until = Kernel.tick_count + EXIT_COOLDOWN_FRAMES
  end

  def render args, outputs = args.outputs, camera = nil
    enemy_rect = camera ? camera.screen_rect(rect) : rect
    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 96)
    inset = 5 + pulse * 2

    outputs.sprites << Render.solid(enemy_rect, :enemy, a: 235)
    outputs.borders << enemy_rect.merge(**Render.color(@state == :chase ? :ember : :ash), a: @state == :chase ? 220 : 125)
    outputs.sprites << Render.solid(
      {
        x: enemy_rect[:x] + inset,
        y: enemy_rect[:y] + inset,
        w: enemy_rect[:w] - inset * 2,
        h: enemy_rect[:h] - inset * 2
      },
      :void,
      a: 210
    )
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

class Player
  SIZE = 34
  SPEED = 4.5
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
    light_size = oscillating_light_size(@light_size, LIGHT_OSCILLATION_AMOUNT)
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def oscillating_light_size base_size, amount
    wave = Math.sin(Kernel.tick_count * Math::PI * 2 / LIGHT_OSCILLATION_FRAMES)
    base_size + wave * amount
  end
end
