class Camera
  FOLLOW_SPEED = 0.12
  ZOOM = 1.75 / WorldScale::FACTOR
  SHAKE_DURATION = 60
  SHAKE_MAGNITUDE = 7

  attr_reader :x, :y, :viewport_w, :viewport_h, :world_w, :world_h

  def initialize viewport_w, viewport_h, world_w, world_h
    @viewport_w = viewport_w
    @viewport_h = viewport_h
    @world_w = world_w
    @world_h = world_h
    @x = 0
    @y = 0
    @shake_started_at = nil
  end

  def follow target
    target_center = target.center
    target_x = (coord(target_center, :x) - visible_w / 2).clamp(0, max_x)
    target_y = (coord(target_center, :y) - visible_h / 2).clamp(0, max_y)
    @x = @x.lerp(target_x, FOLLOW_SPEED).clamp(0, max_x)
    @y = @y.lerp(target_y, FOLLOW_SPEED).clamp(0, max_y)
  end

  def snap_to target
    target_center = target.center
    @x = (coord(target_center, :x) - visible_w / 2).clamp(0, max_x)
    @y = (coord(target_center, :y) - visible_h / 2).clamp(0, max_y)
  end

  def screen_rect rect
    shake = shake_offset
    rect.merge(
      x: (rect[:x] - @x) * ZOOM + shake[:x],
      y: (rect[:y] - @y) * ZOOM + shake[:y],
      w: rect[:w] * ZOOM,
      h: rect[:h] * ZOOM
    )
  end

  def screen_point point
    shake = shake_offset
    { x: (coord(point, :x) - @x) * ZOOM + shake[:x], y: (coord(point, :y) - @y) * ZOOM + shake[:y] }
  end

  def shake!
    @shake_started_at = Kernel.tick_count
  end

  def world_point point
    { x: coord(point, :x) / ZOOM + @x, y: coord(point, :y) / ZOOM + @y }
  end

  def visible_w
    @viewport_w / ZOOM
  end

  def visible_h
    @viewport_h / ZOOM
  end

  def max_x
    [@world_w - visible_w, 0].max
  end

  def max_y
    [@world_h - visible_h, 0].max
  end

  def coord point, key
    return point[key] if point.is_a?(Hash)

    point.send(key)
  end

  def shake_offset
    return { x: 0, y: 0 } unless @shake_started_at

    elapsed = Kernel.tick_count - @shake_started_at
    if elapsed >= SHAKE_DURATION
      @shake_started_at = nil
      return { x: 0, y: 0 }
    end

    falloff = (SHAKE_DURATION - elapsed).fdiv(SHAKE_DURATION)
    magnitude = SHAKE_MAGNITUDE * falloff
    {
      x: Math.sin(elapsed * 2.7) * magnitude,
      y: Math.cos(elapsed * 3.8) * magnitude
    }
  end
end
