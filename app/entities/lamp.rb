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
