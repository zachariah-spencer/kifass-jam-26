class Lamp < Interactable
  SIZE = WorldScale.value(28)
  SPRITE_PATH = "sprites/lamp.png"
  BURNT_OUT_SPRITE_PATH = "sprites/lamp_burnt_out.png"
  FRAME_COUNT = 9
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  FRAME_HOLD = 8
  LIGHT_SIZE = 512
  SACRIFICED_LIGHT_SIZE = 256
  SACRIFICED_LIGHT_ALPHA = 20
  LIGHT_OSCILLATION_AMOUNT = 28

  def initialize x, y, id
    super(x, y, SIZE, SIZE, id: id, word: "LAMP")
    @animation_offset = animation_offset
    @sacrificed_at = nil
  end

  def sacrifice! tick = Kernel.tick_count
    return if sacrificed?

    super
    @sacrificed_at = tick
  end

  def interaction_text
    "Dim firelight shines through the glass."
  end

  def sacrificed_interaction_text
    "You struggle to navigate the space but cannot recall why...."
  end

  def render args, outputs = args.outputs, camera = nil, tick = Kernel.tick_count
    lamp_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << lamp_rect.merge(lamp_sprite(tick))
  end

  def render_light args, outputs = args.outputs, camera = nil, tick = Kernel.tick_count
    light_center = camera ? camera.screen_point(center) : center
    light_size = lamp_light_size(tick)
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      a: lamp_light_alpha(tick),
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def lamp_light_size tick = Kernel.tick_count
    return oscillating_light_size(LIGHT_SIZE, LIGHT_OSCILLATION_AMOUNT, @x + @y, tick) unless sacrificed?

    burn_progress = sacrificed_burnout_progress(tick)
    return SACRIFICED_LIGHT_SIZE unless burn_progress

    LIGHT_SIZE.lerp(SACRIFICED_LIGHT_SIZE, burn_progress)
  end

  def lamp_light_alpha tick = Kernel.tick_count
    return 255 unless sacrificed?

    burn_progress = sacrificed_burnout_progress(tick)
    return SACRIFICED_LIGHT_ALPHA unless burn_progress

    255.lerp(SACRIFICED_LIGHT_ALPHA, burn_progress).to_i
  end

  def lamp_sprite tick = Kernel.tick_count
    frame_index = lamp_frame_index(tick)

    {
      path: sacrificed? ? BURNT_OUT_SPRITE_PATH : SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    }
  end

  def lamp_frame_index tick = Kernel.tick_count
    return (tick + @animation_offset).idiv(FRAME_HOLD) % FRAME_COUNT unless sacrificed?

    frame_index = (tick - @sacrificed_at).idiv(FRAME_HOLD)
    frame_index.clamp(0, FRAME_COUNT - 1)
  end

  def sacrificed_burnout_progress tick = Kernel.tick_count
    return nil unless @sacrificed_at

    progress = (tick - @sacrificed_at).to_f / Game::SACRIFICE_LAMP_GUTTER_FRAMES
    return nil if progress >= 1.0

    progress.clamp(0, 1)
  end

  def animation_offset
    seed = @id.to_s.each_byte.reduce(0) { |total, byte| total * 31 + byte }
    (seed + @x * 17 + @y * 37).to_i % (FRAME_COUNT * FRAME_HOLD)
  end
end
