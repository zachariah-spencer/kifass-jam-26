class Game
  def render_floor args, outputs = args.outputs
    play_area = @camera.screen_rect(current_room.play_area)
    outputs.sprites << Render.solid(play_area, :stone, a: 85)
    render_env_tiles(outputs, cached_env_tile_cells([:room_outline, current_room.id]) { rect_outline_cells(current_room.play_area) })
  end

  def render_room_barriers args, outputs = args.outputs
    render_env_tiles(
      outputs,
      cached_env_tile_cells([:barriers, current_room.id]) do
        current_room.barriers.flat_map { |barrier| rect_fill_cells(barrier) }.uniq
      end
    )

    render_hall_locked_gate(outputs) if current_room.id == :hall
    render_sanctum_locked_gate(outputs) if current_room.id == :sanctum
  end

  def cached_env_tile_cells key
    @env_tile_cache[key] ||= env_tile_layer(yield)
  end

  def rect_outline_cells rect
    min_col, max_col, min_row, max_row = env_cell_bounds(rect)
    cells = []

    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        next unless col == min_col || col == max_col || row == min_row || row == max_row

        cells << [col, row]
      end
    end

    cells
  end

  def rect_fill_cells rect
    min_col, max_col, min_row, max_row = env_cell_bounds(rect)
    cells = []

    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        cells << [col, row]
      end
    end

    cells
  end

  def env_cell_bounds rect
    [
      (rect[:x] / ENV_TILE_SIZE).floor,
      ((rect[:x] + rect[:w] - 1) / ENV_TILE_SIZE).floor,
      (rect[:y] / ENV_TILE_SIZE).floor,
      ((rect[:y] + rect[:h] - 1) / ENV_TILE_SIZE).floor
    ]
  end

  def render_env_tiles outputs, layer, alpha: 255
    cells = layer[:cells]
    occupied = layer[:occupied]
    tile_size = ENV_TILE_SIZE * Camera::ZOOM

    cells.each do |col, row|
      world_rect = {
        x: col * ENV_TILE_SIZE,
        y: row * ENV_TILE_SIZE,
        w: ENV_TILE_SIZE,
        h: ENV_TILE_SIZE
      }
      tile_rect = @camera.screen_rect(world_rect)
      outputs.sprites << tile_rect.merge(
        path: env_tile_path(env_tile_mask(col, row, occupied)),
        w: tile_size,
        h: tile_size,
        a: alpha
      )
    end

    render_env_tile_patches(outputs, layer[:patches], alpha: alpha)
  end

  def env_tile_mask col, row, occupied
    return 0 if env_tile_internal?(col, row, occupied)

    mask = 0
    mask += ENV_TILE_N unless occupied[[col, row + 1]]
    mask += ENV_TILE_E unless occupied[[col + 1, row]]
    mask += ENV_TILE_S unless occupied[[col, row - 1]]
    mask += ENV_TILE_W unless occupied[[col - 1, row]]
    mask
  end

  def env_tile_layer cells
    occupied = cells.each_with_object({}) { |cell, lookup| lookup[cell] = true }
    {
      cells: occupied.keys.reject { |col, row| env_tile_internal?(col, row, occupied) },
      occupied: occupied,
      patches: env_inside_corner_patches(occupied)
    }
  end

  def env_tile_internal? col, row, occupied
    occupied[[col, row + 1]] &&
      occupied[[col + 1, row]] &&
      occupied[[col, row - 1]] &&
      occupied[[col - 1, row]]
  end

  def render_env_tile_patches outputs, patches, alpha: 255
    patch_size = ENV_TILE_PATCH_SIZE * Camera::ZOOM

    patches.each do |patch|
      patch_rect = @camera.screen_rect(
        x: patch[:x],
        y: patch[:y],
        w: ENV_TILE_PATCH_SIZE,
        h: ENV_TILE_PATCH_SIZE
      )
      outputs.sprites << patch_rect.merge(
        path: ENV_TILE_PATCH_PATH,
        w: patch_size,
        h: patch_size,
        a: alpha
      )
    end
  end

  def env_inside_corner_patches occupied
    points = {}

    occupied.each_key do |col, row|
      points[[col, row]] = true
      points[[col + 1, row]] = true
      points[[col, row + 1]] = true
      points[[col + 1, row + 1]] = true
    end

    points.each_key.flat_map do |col, row|
      ne = occupied[[col, row]]
      nw = occupied[[col - 1, row]]
      sw = occupied[[col - 1, row - 1]]
      se = occupied[[col, row - 1]]
      next [] unless [ne, nw, sw, se].count(true) == 3

      env_inside_corner_patch(col, row, ne, nw, sw, se)
    end
  end

  def env_inside_corner_patch col, row, ne, nw, sw, se
    x = col * ENV_TILE_SIZE
    y = row * ENV_TILE_SIZE
    p = ENV_TILE_PATCH_SIZE

    if !ne
      [{ x: x - p, y: y - p }]
    elsif !nw
      [{ x: x, y: y - p }]
    elsif !sw
      [{ x: x, y: y }]
    elsif !se
      [{ x: x - p, y: y }]
    else
      []
    end
  end

  def env_tile_path mask
    ENV_TILE_PATH_TEMPLATE % mask
  end

  def render_hall_locked_gate outputs
    render_locked_gate(
      HALL_BELL_GATE,
      outputs,
      path: LOCKED_GATE_SPRITE_PATH,
      frame_w: LOCKED_GATE_FRAME_W,
      frame_h: LOCKED_GATE_FRAME_H
    )
  end

  def render_sanctum_locked_gate outputs
    render_locked_gate(
      SANCTUM_KEY_GATE_SPRITE,
      outputs,
      path: FINAL_LOCKED_GATE_SPRITE_PATH,
      frame_w: FINAL_LOCKED_GATE_FRAME_W,
      frame_h: FINAL_LOCKED_GATE_FRAME_H
    )
  end

  def render_locked_gate gate, outputs, path:, frame_w:, frame_h:, reverse_frames: false
    update_key_gate_frame

    gate_rect = @camera.screen_rect(gate)
    sprite_frame = reverse_frames ? LOCKED_GATE_FRAME_COUNT - 1 - @key_gate_frame : @key_gate_frame
    outputs.sprites << gate_rect.merge(
      path: path,
      tile_x: sprite_frame % LOCKED_GATE_FRAME_COLUMNS * frame_w,
      tile_y: sprite_frame.idiv(LOCKED_GATE_FRAME_COLUMNS) * frame_h,
      tile_w: frame_w,
      tile_h: frame_h
    )
  end

  def render_archive_safe_paths args, outputs = args.outputs
    return unless @current_room_id == :archive
    return unless @learned_words.include?("MIRROR")
    return if @sacrificed_words.include?("MIRROR")

    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 120)
    render_env_tiles(
      outputs,
      cached_env_tile_cells(:archive_safe_paths) do
        archive_safe_paths.flat_map { |path| rect_fill_cells(path) }.uniq
      end,
      alpha: (55 + pulse * 18).to_i
    )
  end
end
