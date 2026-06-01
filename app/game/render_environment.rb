class Game
  def render_floor args, outputs = args.outputs
  end

  def render_room_barriers args, outputs = args.outputs
    render_env_tiles(
      outputs,
      cached_env_tile_cells([:barriers, current_room.id]) do
        current_room.barriers.flat_map { |barrier| rect_fill_cells(barrier) }.uniq
      end
    )

    render_locked_gates(outputs)
  end

  def cached_env_tile_cells key
    @env_tile_cache[key] ||= env_tile_layer(yield)
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
    visible = env_visible_rect(ENV_TILE_SIZE)
    transform = env_render_transform

    env_layer_render_cells(layer).each do |cell|
      next unless env_rect_visible?(cell, visible)

      outputs.sprites << {
        x: (cell[:x] - transform[:x]) * transform[:zoom] + transform[:shake_x],
        y: (cell[:y] - transform[:y]) * transform[:zoom] + transform[:shake_y],
        w: cell[:w] * transform[:zoom],
        h: cell[:h] * transform[:zoom],
        path: cell[:path],
        a: alpha
      }
    end

    render_env_tile_patches(outputs, env_layer_render_patches(layer), visible, transform, alpha: alpha)
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
    visible_cells = occupied.keys.reject { |col, row| env_tile_internal?(col, row, occupied) }
    patches = env_inside_corner_patches(occupied)
    {
      cells: visible_cells,
      occupied: occupied,
      patches: patches,
      render_cells: env_tile_render_cells(visible_cells, occupied),
      render_patches: env_tile_render_patches(patches)
    }
  end

  def env_tile_layer_without_patches cells
    occupied = cells.each_with_object({}) { |cell, lookup| lookup[cell] = true }
    visible_cells = occupied.keys.reject { |col, row| env_tile_internal?(col, row, occupied) }
    {
      cells: visible_cells,
      occupied: occupied,
      patches: [],
      render_cells: env_tile_render_cells(visible_cells, occupied),
      render_patches: []
    }
  end

  def env_tile_render_cells cells, occupied
    cells.map do |col, row|
      {
        x: col * ENV_TILE_SIZE,
        y: row * ENV_TILE_SIZE,
        w: ENV_TILE_SIZE,
        h: ENV_TILE_SIZE,
        path: env_tile_path(env_tile_mask(col, row, occupied))
      }
    end
  end

  def env_tile_render_patches patches
    patches.map do |patch|
      {
        x: patch[:x],
        y: patch[:y],
        w: ENV_TILE_PATCH_SIZE,
        h: ENV_TILE_PATCH_SIZE,
        path: ENV_TILE_PATCH_PATH
      }
    end
  end

  def env_layer_render_cells layer
    layer[:render_cells] ||= env_tile_render_cells(layer[:cells], layer[:occupied])
  end

  def env_layer_render_patches layer
    layer[:render_patches] ||= env_tile_render_patches(layer[:patches])
  end

  def env_tile_internal? col, row, occupied
    occupied[[col, row + 1]] &&
      occupied[[col + 1, row]] &&
      occupied[[col, row - 1]] &&
      occupied[[col - 1, row]]
  end

  def render_env_tile_patches outputs, patches, visible, transform, alpha: 255
    patches.each do |patch|
      next unless env_rect_visible?(patch, visible)

      outputs.sprites << {
        x: (patch[:x] - transform[:x]) * transform[:zoom] + transform[:shake_x],
        y: (patch[:y] - transform[:y]) * transform[:zoom] + transform[:shake_y],
        w: patch[:w] * transform[:zoom],
        h: patch[:h] * transform[:zoom],
        path: patch[:path],
        a: alpha
      }
    end
  end

  def env_render_transform
    shake = @camera.shake_offset
    {
      x: @camera.x,
      y: @camera.y,
      zoom: @camera.zoom,
      shake_x: shake[:x],
      shake_y: shake[:y]
    }
  end

  def env_visible_rect margin
    {
      x: @camera.x - margin,
      y: @camera.y - margin,
      w: @camera.visible_w + margin * 2,
      h: @camera.visible_h + margin * 2
    }
  end

  def env_rect_visible? rect, visible
    rect[:x] + rect[:w] >= visible[:x] &&
      rect[:x] <= visible[:x] + visible[:w] &&
      rect[:y] + rect[:h] >= visible[:y] &&
      rect[:y] <= visible[:y] + visible[:h]
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

  def render_locked_gates outputs
    current_room.locked_gates.each do |gate|
      render_locked_gate(
        gate[:id],
        gate[:sprite_rect],
        outputs,
        path: gate[:path],
        frame_w: gate[:frame_w],
        frame_h: gate[:frame_h]
      )
    end
  end

  def render_locked_gate gate_id, gate, outputs, path:, frame_w:, frame_h:, reverse_frames: false
    frame = update_key_gate_frame(gate_id)

    gate_rect = key_gate_slam_rect(@camera.screen_rect(gate))
    sprite_frame = reverse_frames ? LOCKED_GATE_FRAME_COUNT - 1 - frame : frame
    outputs.sprites << gate_rect.merge(
      path: path,
      tile_x: sprite_frame % LOCKED_GATE_FRAME_COLUMNS * frame_w,
      tile_y: sprite_frame.idiv(LOCKED_GATE_FRAME_COLUMNS) * frame_h,
      tile_w: frame_w,
      tile_h: frame_h
    )
    render_key_gate_power_up(gate_rect, outputs)
  end

  def render_archive_safe_paths args, outputs = args.outputs
    return unless @current_room_id == :archive
    return unless @learned_words.include?("MIRROR") || @sacrificed_words.include?("MIRROR")

    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 120)
    mirror_sacrifice_effect = sacrifice_effect("MIRROR", SACRIFICE_MIRROR_FLICKER_FRAMES)
    if mirror_sacrifice_effect
      render_mirror_sacrifice_flicker(outputs, mirror_sacrifice_effect)
      return
    end

    if @sacrificed_words.include?("MIRROR")
      render_env_tiles(
        outputs,
        cached_env_tile_cells(:sacrificed_mirror_safe_paths) { sacrificed_mirror_safe_path_cells },
        alpha: (24 + pulse * 8).to_i
      )
    else
      base_alpha = (70 + pulse * 24).to_i
      render_env_tiles(
        outputs,
        cached_env_tile_cells(:archive_safe_paths) { archive_safe_path_cells },
        alpha: mirror_safe_path_alpha(base_alpha)
      )
    end
  end

  def render_key_gate_power_up gate_rect, outputs
    progress = learned_word_effect_progress("KEY", LEARNED_KEY_EFFECT_FRAMES)
    return unless progress

    pulse = Math.sin(progress * Math::PI)
    scale = 1.0.lerp(2.5, pulse)
    alpha = (230 * (1.0 - progress)).to_i
    overlay = scaled_rect(gate_rect, scale)
    outputs.sprites << overlay.merge(path: :solid, r: 255, g: 255, b: 255, a: (alpha * 0.22).to_i)
    outputs.borders << overlay.merge(r: 255, g: 255, b: 255, a: alpha)
  end

  def key_gate_slam_rect gate_rect
    effect = sacrifice_effect("KEY", SACRIFICE_KEY_SLAM_FRAMES)
    return gate_rect unless effect

    pulse = Math.sin(effect[:progress] * Math::PI)
    jitter = Math.sin(Kernel.tick_count * Math::PI * 2 / 3) * 5 * (1.0 - effect[:progress])
    rect = scaled_rect(gate_rect, 1.0 + pulse * 0.08)
    rect.merge(x: rect[:x] + jitter)
  end

  def mirror_safe_path_alpha base_alpha
    total_frames = LEARNED_MIRROR_EFFECT_IN_FRAMES + LEARNED_MIRROR_EFFECT_SETTLE_FRAMES
    progress = learned_word_effect_progress("MIRROR", total_frames)
    return base_alpha unless progress

    in_progress = LEARNED_MIRROR_EFFECT_IN_FRAMES.to_f / total_frames
    if progress <= in_progress
      local_progress = (progress / in_progress).clamp(0, 1)
      80.lerp(135, local_progress).to_i
    else
      local_progress = ((progress - in_progress) / (1.0 - in_progress)).clamp(0, 1)
      135.lerp(base_alpha, local_progress).to_i
    end
  end

  def scaled_rect rect, scale
    {
      x: rect[:x] + rect[:w] * (1.0 - scale) / 2,
      y: rect[:y] + rect[:h] * (1.0 - scale) / 2,
      w: rect[:w] * scale,
      h: rect[:h] * scale
    }
  end

  def archive_safe_path_cells
    @archive_safe_path_cells ||= archive_safe_paths.flat_map { |path| rect_fill_cells(path) }.uniq
  end

  def sacrificed_mirror_safe_path_cells
    @sacrificed_mirror_safe_path_cells ||= begin
      cells = archive_safe_path_cells
      keep_count = (cells.length * 0.25).ceil
      cells.sort_by { |col, row| sacrificed_mirror_cell_seed(col, row) }.first(keep_count)
    end
  end

  def sacrificed_mirror_cell_seed col, row
    ((col * 73_856_093) ^ (row * 19_349_663) ^ 0x4d1_220).abs
  end

  def render_mirror_sacrifice_flicker outputs, effect
    progress = effect[:progress]
    tick_gate = Kernel.tick_count.idiv(4)
    alpha = (160 * (1.0 - progress)).to_i.clamp(18, 180)
    visible = env_visible_rect(ENV_TILE_SIZE)
    transform = env_render_transform
    layer = cached_env_tile_cells(:archive_safe_paths) { archive_safe_path_cells }

    env_layer_render_cells(layer).each do |cell|
      next unless env_rect_visible?(cell, visible)

      col = (cell[:x] / ENV_TILE_SIZE).floor
      row = (cell[:y] / ENV_TILE_SIZE).floor
      seed = sacrificed_mirror_cell_seed(col, row)
      cutoff = (seed % 1000) / 1000.0
      next unless cutoff > progress || (seed + tick_gate) % 5 == 0

      outputs.sprites << {
        x: (cell[:x] - transform[:x]) * transform[:zoom] + transform[:shake_x],
        y: (cell[:y] - transform[:y]) * transform[:zoom] + transform[:shake_y],
        w: cell[:w] * transform[:zoom],
        h: cell[:h] * transform[:zoom],
        path: cell[:path],
        a: alpha
      }
    end
  end
end
