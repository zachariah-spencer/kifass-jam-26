class Camera
  FOLLOW_SPEED = 0.12
  ZOOM = 0.85

  attr_reader :x, :y, :viewport_w, :viewport_h, :world_w, :world_h

  def initialize viewport_w, viewport_h, world_w, world_h
    @viewport_w = viewport_w
    @viewport_h = viewport_h
    @world_w = world_w
    @world_h = world_h
    @x = 0
    @y = 0
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
    rect.merge(
      x: (rect[:x] - @x) * ZOOM,
      y: (rect[:y] - @y) * ZOOM,
      w: rect[:w] * ZOOM,
      h: rect[:h] * ZOOM
    )
  end

  def screen_point point
    { x: (coord(point, :x) - @x) * ZOOM, y: (coord(point, :y) - @y) * ZOOM }
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
end
