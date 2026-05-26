class Camera
  FOLLOW_SPEED = 0.12

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
    target_x = (coord(target_center, :x) - @viewport_w / 2).clamp(0, max_x)
    target_y = (coord(target_center, :y) - @viewport_h / 2).clamp(0, max_y)
    @x = @x.lerp(target_x, FOLLOW_SPEED).clamp(0, max_x)
    @y = @y.lerp(target_y, FOLLOW_SPEED).clamp(0, max_y)
  end

  def snap_to target
    target_center = target.center
    @x = (coord(target_center, :x) - @viewport_w / 2).clamp(0, max_x)
    @y = (coord(target_center, :y) - @viewport_h / 2).clamp(0, max_y)
  end

  def screen_rect rect
    rect.merge(x: rect[:x] - @x, y: rect[:y] - @y)
  end

  def screen_point point
    { x: coord(point, :x) - @x, y: coord(point, :y) - @y }
  end

  def world_point point
    { x: coord(point, :x) + @x, y: coord(point, :y) + @y }
  end

  def max_x
    [@world_w - @viewport_w, 0].max
  end

  def max_y
    [@world_h - @viewport_h, 0].max
  end

  def coord point, key
    return point[key] if point.is_a?(Hash)

    point.send(key)
  end
end
