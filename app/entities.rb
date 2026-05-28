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

    outputs.borders << rect.merge(**Render.color(:flame), a: 210)
    outputs.sprites << Render.solid(rect, :flame, a: 24)
  end

  def render_light args, outputs = args.outputs, camera = nil
  end

  def oscillating_light_size base_size, amount, phase = 0
    wave = Math.sin((Kernel.tick_count + phase) * Math::PI * 2 / LIGHT_OSCILLATION_FRAMES)
    base_size + wave * amount
  end
end

class Lamp < Interactable
  SIZE = WorldScale.value(28)
  LIGHT_SIZE = 512
  LIGHT_OSCILLATION_AMOUNT = 28

  def initialize x, y, id
    super(x, y, SIZE, SIZE, id: id, word: "LAMP")
  end

  def interaction_text
    "Dim firelight shines through the glass."
  end

  def sacrificed_interaction_text
    "You struggle to navigate the space but cannot recall why...."
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

  attr_reader :target_room_id, :target_spawn_id, :unlock_altar_id

  def initialize x, y, id, target_room_id, target_spawn_id, unlock_altar_id: nil
    super(x, y, W, H, id: id)
    @target_room_id = target_room_id
    @target_spawn_id = target_spawn_id
    @unlock_altar_id = unlock_altar_id
    @locked = !!unlock_altar_id
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
    @locked = false
  end

  def interaction_text
    return "The passage is sealed. The altar waits for a name." if locked?

    "The passage exhales cold air."
  end

  def render args, outputs = args.outputs, camera = nil
    exit_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(exit_rect, :void, a: locked? ? 245 : 210)
    outputs.borders << exit_rect.merge(**Render.color(locked? ? :brass : :ember))
    return unless locked?

    outputs.sprites << Render.solid(
      {
        x: exit_rect[:x] + 18,
        y: exit_rect[:y] + 18,
        w: exit_rect[:w] - 36,
        h: exit_rect[:h] - 36
      },
      :wall,
      a: 190
    )
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
  W = WorldScale.value(42)
  H = WorldScale.value(24)

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
    color = sacrificed? ? :ash : :brass
    outputs.sprites << Render.solid(
      {
        x: key_rect[:x],
        y: key_rect[:y] + key_rect[:h] / 2 - 4,
        w: key_rect[:w],
        h: 8
      },
      color,
      a: sacrificed? ? 95 : 230
    )
    outputs.sprites << {
      x: key_rect[:x],
      y: key_rect[:y],
      w: key_rect[:h],
      h: key_rect[:h],
      path: "sprites/circle/yellow.png",
      **Render.color(color),
      a: sacrificed? ? 95 : 230
    }
    outputs.sprites << Render.solid(
      {
        x: key_rect[:x] + key_rect[:w] - 12,
        y: key_rect[:y],
        w: 6,
        h: key_rect[:h] / 2
      },
      color,
      a: sacrificed? ? 95 : 230
    )
  end
end

class Bell < Interactable
  W = WorldScale.value(60)
  H = WorldScale.value(54)

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
    color = sacrificed? ? :ash : :brass

    3.times do |index|
      bell = {
        x: bell_rect[:x] + index * bell_rect[:w] / 3 + 5,
        y: bell_rect[:y] + 10,
        w: bell_rect[:w] / 3 - 8,
        h: bell_rect[:h] - 16
      }
      outputs.sprites << Render.solid(bell, color, a: sacrificed? ? 85 : 220)
      outputs.borders << bell.merge(**Render.color(sacrificed? ? :ash : :flame), a: sacrificed? ? 90 : 180)
      outputs.sprites << Render.solid(
        {
          x: bell[:x] + bell[:w] / 2 - 2,
          y: bell[:y] - 5,
          w: 4,
          h: 8
        },
        color,
        a: sacrificed? ? 85 : 220
      )
    end

    outputs.sprites << Render.solid(
      {
        x: bell_rect[:x],
        y: bell_rect[:y] + bell_rect[:h] - 8,
        w: bell_rect[:w],
        h: 6
      },
      :wall,
      a: 230
    )
  end
end

class NamelessThing
  SIZE = WorldScale.value(44)
  PATROL_SPEED = 1.45 * WorldScale::FACTOR
  CHASE_SPEED = 2.15 * WorldScale::FACTOR
  BELL_SACRIFICED_CHASE_SPEED = 3.05 * WorldScale::FACTOR
  CHASE_RADIUS = WorldScale.value(420)
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

    @state = close_to_player?(player) ? :chase : :patrol

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
    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 96)
    inset = 5 + pulse * 2

    border_color = @state == :stunned ? :flame : (@state == :chase ? :ember : :ash)
    border_alpha = @state == :stunned ? 245 : (@state == :chase ? 220 : 125)
    outputs.sprites << Render.solid(enemy_rect, :enemy, a: @state == :stunned ? 180 : 235)
    outputs.borders << enemy_rect.merge(**Render.color(border_color), a: border_alpha)
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
  SIZE = 256
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

  def center
    { x: @x + @w / 2, y: @y + @h / 2 }
  end

  def render args, outputs = args.outputs, camera = nil, alpha = 255
    player_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << player_rect.merge(path: "sprites/t-pose/white.png", **Render.color(:player), a: alpha)
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
