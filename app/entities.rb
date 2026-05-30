class Interactable
  LIGHT_OSCILLATION_FRAMES = 72
  PASSIVE_LIGHT_ALPHA = 50
  PASSIVE_LIGHT_PADDING = WorldScale.value(96)

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

  def render_highlight args, outputs = args.outputs, camera = nil
    highlight_rect = camera ? camera.screen_rect(rect) : rect
    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 60)
    inset = -6 - pulse * 2
    rect = {
      x: highlight_rect[:x] + inset,
      y: highlight_rect[:y] + inset,
      w: highlight_rect[:w] - inset * 2,
      h: highlight_rect[:h] - inset * 2
    }

    outputs.borders << rect.merge(**Render.color(:ash), a: 210)
    outputs.sprites << Render.solid(rect, :ash, a: 24)
  end

  def render_light args, outputs = args.outputs, camera = nil
    light_center = camera ? camera.screen_point(center) : center
    light_size = [@w, @h].max + PASSIVE_LIGHT_PADDING
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      a: PASSIVE_LIGHT_ALPHA,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def oscillating_light_size base_size, amount, phase = 0
    wave = Math.sin((Kernel.tick_count + phase) * Math::PI * 2 / LIGHT_OSCILLATION_FRAMES)
    base_size + wave * amount
  end
end

class Lamp < Interactable
  SIZE = WorldScale.value(28)
  SPRITE_PATH = "sprites/lamp.png"
  BURNT_OUT_SPRITE_PATH = "sprites/lamp_burnt_out.png"
  FRAME_COUNT = 9
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  FRAME_HOLD = 8
  LIGHT_SIZE = 512
  SACRIFICED_LIGHT_SIZE = 512
  SACRIFICED_LIGHT_ALPHA = 70
  LIGHT_OSCILLATION_AMOUNT = 28

  def initialize x, y, id
    super(x, y, SIZE, SIZE, id: id, word: "LAMP")
    @animation_offset = animation_offset
    @sacrificed_at = nil
  end

  def sacrifice!
    return if sacrificed?

    super
    @sacrificed_at = Kernel.tick_count
  end

  def interaction_text
    "Dim firelight shines through the glass."
  end

  def sacrificed_interaction_text
    "You struggle to navigate the space but cannot recall why...."
  end

  def render args, outputs = args.outputs, camera = nil
    lamp_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << lamp_rect.merge(lamp_sprite)
  end

  def render_light args, outputs = args.outputs, camera = nil
    light_center = camera ? camera.screen_point(center) : center
    light_size = sacrificed? ? SACRIFICED_LIGHT_SIZE : oscillating_light_size(LIGHT_SIZE, LIGHT_OSCILLATION_AMOUNT, @x + @y)
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      a: sacrificed? ? SACRIFICED_LIGHT_ALPHA : 255,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def lamp_sprite
    frame_index = lamp_frame_index

    {
      path: sacrificed? ? BURNT_OUT_SPRITE_PATH : SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    }
  end

  def lamp_frame_index
    return (Kernel.tick_count + @animation_offset).idiv(FRAME_HOLD) % FRAME_COUNT unless sacrificed?

    @sacrificed_at.frame_index(
      count: FRAME_COUNT,
      hold_for: FRAME_HOLD,
      loop: false
    ) || FRAME_COUNT - 1
  end

  def animation_offset
    seed = @id.to_s.each_byte.reduce(0) { |total, byte| total * 31 + byte }
    (seed + @x * 17 + @y * 37).to_i % (FRAME_COUNT * FRAME_HOLD)
  end
end

class Altar < Interactable
  W = 512
  H = 512
  SPRITE_PATH = "sprites/altar.png"
  BREAK_SPRITE_PATH = "sprites/altar_break_9.png"
  BREAK_FRAME_COUNT = 9
  BREAK_FRAME_COLUMNS = 3
  BREAK_FRAME_SIZE = 1024
  BREAK_FRAME_HOLD = 5

  def initialize x, y, id
    super(x, y, W, H, id: id)
    @sacrificed_at = nil
  end

  def sacrifice!
    return if sacrificed?

    super
    @sacrificed_at = Kernel.tick_count
  end

  def interact game
    return "The altar is spent." if sacrificed?

    game.open_altar(self)
  end

  def interaction_text
    return "The altar is spent." if sacrificed?

    "The altar waits for a name."
  end

  def render args, outputs = args.outputs, camera = nil
    altar_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << altar_sprite(altar_rect)
  end

  def altar_sprite altar_rect
    return altar_rect.merge(path: SPRITE_PATH) unless sacrificed?

    frame_index = @sacrificed_at.frame_index(
      count: BREAK_FRAME_COUNT,
      hold_for: BREAK_FRAME_HOLD,
      loop: false
    ) || BREAK_FRAME_COUNT - 1

    altar_rect.merge(
      path: BREAK_SPRITE_PATH,
      tile_x: frame_index % BREAK_FRAME_COLUMNS * BREAK_FRAME_SIZE,
      tile_y: frame_index.idiv(BREAK_FRAME_COLUMNS) * BREAK_FRAME_SIZE,
      tile_w: BREAK_FRAME_SIZE,
      tile_h: BREAK_FRAME_SIZE
    )
  end
end

class NameAltar < Altar
  def interact game
    return "The altar is spent." if sacrificed?
    return "The final altar is cold. Two names must be taken first." unless game.sanctum_final_altar_active?

    game.open_altar(self)
  end

  def interaction_text
    return "The altar is spent." if sacrificed?

    "The final altar waits for the last name."
  end

end

class FinalDoor < Interactable
  W = WorldScale.value(118)
  H = WorldScale.value(188)

  def initialize x, y, id
    super(x, y, W, H, id: id)
  end

  def interaction_text
    "The door waits for the last name."
  end

  def render args, outputs = args.outputs, camera = nil, open = false
    door_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(door_rect, :void, a: open ? 115 : 250)
    outputs.borders << door_rect.merge(**Render.color(:flame), a: 235)

    inner = {
      x: door_rect[:x] + (open ? 34 : 14),
      y: door_rect[:y] + 16,
      w: open ? 20 : door_rect[:w] - 28,
      h: door_rect[:h] - 32
    }
    outputs.sprites << Render.solid(inner, open ? :wall : :void, a: open ? 215 : 0)
    outputs.borders << inner.merge(**Render.color(:brass), a: 210)
    return if open

    lock = {
      x: door_rect[:x] + door_rect[:w] / 2 - 18,
      y: door_rect[:y] + door_rect[:h] / 2 - 18,
      w: 36,
      h: 36
    }
    outputs.sprites << Render.solid(lock, :wall, a: 235)
    outputs.borders << lock.merge(**Render.color(:flame), a: 220)
    outputs.labels << Render.label(
      door_rect[:x] + door_rect[:w] / 2,
      door_rect[:y] + door_rect[:h] - 28,
      "NAME",
      :flame,
      size_enum: -2,
      alignment_enum: 1
    )
  end
end

class Exit < Interactable
  W = WorldScale.value(92)
  H = WorldScale.value(92)
  SPRITE_PATH = "sprites/door.png"
  FRAME_COUNT = 8
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  FRAME_HOLD = 5

  attr_reader :target_room_id, :target_spawn_id, :unlock_altar_id

  def initialize x, y, id, target_room_id, target_spawn_id, unlock_altar_id: nil
    super(x, y, W, H, id: id)
    @target_room_id = target_room_id
    @target_spawn_id = target_spawn_id
    @unlock_altar_id = unlock_altar_id
    @locked = !!unlock_altar_id
    @unlocked_at = @locked ? nil : Kernel.tick_count
  end

  def interact game
    return "The passage is sealed. The altar waits for a name." unless can_traverse?

    game.request_room_transition(@target_room_id, @target_spawn_id, self)
  end

  def locked?
    @locked
  end

  def can_traverse?
    !locked?
  end

  def unlock!
    return unless @locked

    @locked = false
    @unlocked_at = Kernel.tick_count
  end

  def interaction_text
    return "The passage is sealed. The altar waits for a name." if locked?

    "The passage exhales cold air."
  end

  def render args, outputs = args.outputs, camera = nil
    exit_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << exit_sprite(exit_rect)
  end

  def exit_sprite exit_rect
    frame_index = exit_frame_index

    exit_rect.merge(
      path: SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    )
  end

  def exit_frame_index
    return 0 unless @unlocked_at

    @unlocked_at.frame_index(
      count: FRAME_COUNT,
      hold_for: FRAME_HOLD,
      loop: false
    ) || FRAME_COUNT - 1
  end
end

class Mirror < Interactable
  W = WorldScale.value(54)
  H = WorldScale.value(74)

  def initialize x, y, id
    super(x, y, W, H, id: id, word: "MIRROR")
  end

  def interaction_text
    "A cold reflection shows paths the floor refuses to keep."
  end

  def sacrificed_interaction_text
    "The frame holds only dust-dark glass."
  end

  def render args, outputs = args.outputs, camera = nil
    mirror_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(mirror_rect, sacrificed? ? :wall : :void, a: 225)
    outputs.borders << mirror_rect.merge(**Render.color(sacrificed? ? :ash : :brass), a: 220)

    glass = {
      x: mirror_rect[:x] + 10,
      y: mirror_rect[:y] + 10,
      w: mirror_rect[:w] - 20,
      h: mirror_rect[:h] - 20
    }
    outputs.sprites << Render.solid(glass, sacrificed? ? :stone : :ash, a: sacrificed? ? 80 : 58)
    outputs.borders << glass.merge(**Render.color(:ash), a: sacrificed? ? 70 : 140)
  end
end

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

  def render args, outputs = args.outputs, camera = nil
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

    bounds ||= {
      x: WorldScale.value(52),
      y: WorldScale.value(58),
      w: WorldScale.value(Grid.w - 104),
      h: WorldScale.value(Grid.h - 116)
    }
    @x = (@x + @dx).clamp(bounds[:x], bounds[:x] + bounds[:w] - @w)
    resolve_barrier_collisions(:x, barriers)
    @y = (@y + @dy).clamp(bounds[:y], bounds[:y] + bounds[:h] - @h)
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

  def force_run_animation!
    @animation_override = :run
    @run_started_at = Kernel.tick_count
  end

  def force_idle_animation!
    @animation_override = :idle
    @idle_started_at = Kernel.tick_count
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

  def render args, outputs = args.outputs, camera = nil, alpha = 255
    player_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << player_rect.merge(player_sprite).merge(a: alpha)
  end

  def player_sprite
    running = @animation_override == :run || (!@animation_override && moving?)
    running ? animation_sprite(RUN_SPRITE_PATH, RUN_FRAME_COUNT, RUN_FRAME_COLUMNS, RUN_FRAME_SIZE, RUN_FRAME_HOLD, @run_started_at) :
              animation_sprite(IDLE_SPRITE_PATH, IDLE_FRAME_COUNT, IDLE_FRAME_COLUMNS, IDLE_FRAME_SIZE, IDLE_FRAME_HOLD, @idle_started_at)
  end

  def animation_sprite path, frame_count, frame_columns, frame_size, frame_hold, started_at
    frame_index = started_at.frame_index(
      count: frame_count,
      hold_for: frame_hold,
      repeat: true
    ) || 0

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
