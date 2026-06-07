class Interactable
  LIGHT_OSCILLATION_FRAMES = 72
  PASSIVE_LIGHT_ALPHA = 20
  PASSIVE_LIGHT_PADDING = WorldScale.value(96)

  attr_accessor :x, :y
  attr_reader :id, :w, :h, :word

  def initialize x, y, w, h, options = nil
    options ||= {}
    @x = x
    @y = y
    @w = w
    @h = h
    @id = options[:id]
    @word = options[:word]
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

  def interact game, args = nil
    game.interaction_text_for(self, args)
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
    light_size = [@w, @h].max / 2# + PASSIVE_LIGHT_PADDING
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
