class FinalDoor < Interactable
  W = WorldScale.value(118)
  H = WorldScale.value(188)
  RENDER_SIZE = 512
  SPRITE_PATH = "sprites/final_door.png"
  FRAME_COUNT = 8
  FRAME_COLUMNS = 3
  FRAME_SIZE = 1024
  FRAME_HOLD = 9

  def initialize x, y, id
    super(x, y, W, H, id: id)
    @opened_at = nil
  end

  def interaction_text
    "The door waits for the last name."
  end

  def render args, outputs = args.outputs, camera = nil, open = false
    door_rect = camera ? camera.screen_rect(render_rect) : render_rect
    frame_index = current_frame_index(open)
    outputs.sprites << door_rect.merge(
      path: SPRITE_PATH,
      tile_x: frame_index % FRAME_COLUMNS * FRAME_SIZE,
      tile_y: frame_index.idiv(FRAME_COLUMNS) * FRAME_SIZE,
      tile_w: FRAME_SIZE,
      tile_h: FRAME_SIZE
    )
  end

  def render_rect
    {
      x: center[:x] - RENDER_SIZE / 2,
      y: center[:y] - RENDER_SIZE / 2,
      w: RENDER_SIZE,
      h: RENDER_SIZE
    }
  end

  def current_frame_index open
    unless open
      @opened_at = nil
      return 0
    end

    @opened_at ||= Kernel.tick_count
    frame_index = (Kernel.tick_count - @opened_at).idiv(FRAME_HOLD)
    frame_index.clamp(0, FRAME_COUNT - 1)
  end
end
