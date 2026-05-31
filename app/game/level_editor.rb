class LevelEditorCamera
  attr_reader :x, :y, :zoom, :world_w, :world_h

  def initialize world_w, world_h
    @world_w = world_w
    @world_h = world_h
    @zoom = [Grid.w.fdiv(world_w), Grid.h.fdiv(world_h)].min * 0.92
    @zoom = @zoom.clamp(0.05, 4.0)
    @x = (world_w - visible_w) / 2
    @y = (world_h - visible_h) / 2
  end

  def pan dx, dy
    @x += dx / @zoom
    @y += dy / @zoom
  end

  def zoom_by factor, screen_point
    before = world_point(screen_point)
    @zoom = (@zoom * factor).clamp(0.035, 3.0)
    after = world_point(screen_point)
    @x += before[:x] - after[:x]
    @y += before[:y] - after[:y]
  end

  def screen_rect rect
    rect.merge(
      x: (rect[:x] - @x) * @zoom,
      y: (rect[:y] - @y) * @zoom,
      w: rect[:w] * @zoom,
      h: rect[:h] * @zoom
    )
  end

  def screen_point point
    { x: (coord(point, :x) - @x) * @zoom, y: (coord(point, :y) - @y) * @zoom }
  end

  def world_point point
    { x: coord(point, :x) / @zoom + @x, y: coord(point, :y) / @zoom + @y }
  end

  def shake_offset
    { x: 0, y: 0 }
  end

  def visible_w
    Grid.w / @zoom
  end

  def visible_h
    Grid.h / @zoom
  end

  def coord point, key
    return point[key] if point.is_a?(Hash)

    point.send(key)
  end

end

class Game
  LEVEL_EDITOR_ENABLED = true
  EDITOR_RECT_SIZE = 1
  EDITOR_TOOLS = [
    { key: "barrier", label: "Barrier", collection: "barriers", rect: true },
    { key: "safe_path", label: "Safe Path", collection: "safe_paths", rect: true },
    { key: "gate", label: "Gate", gate: true },
    { key: "final_gate", label: "Final Gate", gate: true, final_gate: true },
    { key: "lamp", label: "Lamp", object: true },
    { key: "bell", label: "Bell", object: true },
    { key: "altar", label: "Altar", object: true },
    { key: "name_altar", label: "Name Altar", object: true },
    { key: "mirror", label: "Mirror", object: true },
    { key: "archive_key", label: "Key", object: true },
    { key: "exit", label: "Exit", object: true },
    { key: "final_door", label: "Final Door", object: true },
    { key: "enemy", label: "Enemy Spawn", enemy: true }
  ]

  def handle_level_editor_toggle args
    return false unless LEVEL_EDITOR_ENABLED
    return false unless args.inputs.keyboard.key_down.l

    level_editor_active? ? close_level_editor : open_level_editor
    true
  end

  def level_editor_active?
    !!@level_editor
  end

  def open_level_editor
    close_altar
    clear_interaction_text
    clear_pointer_gesture
    @level_editor = {
      room_id: @current_room_id,
      camera: LevelEditorCamera.new(current_room.world_w, current_room.world_h),
      tool_index: 0,
      drag_start: nil,
      last_painted_cell: nil,
      saved_camera: @camera,
      saved_player: { x: @player.x, y: @player.y }
    }
  end

  def close_level_editor
    save_level_data
    if @level_editor
      @camera = @level_editor[:saved_camera] if @level_editor[:saved_camera]
      if @player && @level_editor[:saved_player]
        @player.x = @level_editor[:saved_player][:x]
        @player.y = @level_editor[:saved_player][:y]
      end
    end
    @level_editor = nil
  end

  def update_level_editor args
    return unless level_editor_active?
    return if handle_level_editor_toggle(args)

    update_level_editor_selection(args)
    update_level_editor_camera(args)
    update_level_editor_mouse(args)
  end

  def update_level_editor_selection args
    keyboard = args.inputs.keyboard
    key = keyboard.key_down
    char = key.char
    change_level_editor_tool(-1) if char == "["
    change_level_editor_tool(1) if char == "]"

    number_keys = [keyboard.one, keyboard.two, keyboard.three, keyboard.four, keyboard.five, keyboard.six, keyboard.seven, keyboard.eight, keyboard.nine]
    number_keys.each_with_index do |pressed, index|
      @level_editor[:tool_index] = index if pressed && EDITOR_TOOLS[index]
    end
    @level_editor[:tool_index] = 9 if keyboard.zero && EDITOR_TOOLS[9]
  end

  def change_level_editor_tool amount
    @level_editor[:tool_index] = (@level_editor[:tool_index] + amount) % EDITOR_TOOLS.length
  end

  def update_level_editor_camera args
    camera = @level_editor[:camera]
    speed = args.inputs.keyboard.shift ? 36 : 18
    camera.pan(-speed, 0) if args.inputs.keyboard.a || args.inputs.keyboard.left
    camera.pan(speed, 0) if args.inputs.keyboard.d || args.inputs.keyboard.right
    camera.pan(0, speed) if args.inputs.keyboard.w || args.inputs.keyboard.up
    camera.pan(0, -speed) if args.inputs.keyboard.s || args.inputs.keyboard.down
    camera.zoom_by(1.1, args.inputs.mouse) if args.inputs.keyboard.equal_sign || args.inputs.keyboard.plus
    camera.zoom_by(0.9, args.inputs.mouse) if args.inputs.keyboard.hyphen || args.inputs.keyboard.minus
  end

  def update_level_editor_mouse args
    mouse = args.inputs.mouse
    cell = editor_mouse_cell(mouse)
    return unless cell

    if mouse_right_down?(mouse)
      remove_level_editor_at(cell)
      commit_level_editor_change
      return
    end

    if mouse_left_down?(mouse)
      @level_editor[:drag_start] = cell
      @level_editor[:last_painted_cell] = nil
      place_level_editor_at(cell) unless args.inputs.keyboard.shift && editor_rect_tool?
    elsif mouse_left_held?(mouse) && !args.inputs.keyboard.shift && editor_paint_tool?
      return if @level_editor[:last_painted_cell] == cell

      place_level_editor_at(cell)
    elsif mouse_left_up?(mouse)
      if args.inputs.keyboard.shift && editor_rect_tool? && @level_editor[:drag_start]
        place_level_editor_rect(@level_editor[:drag_start], cell)
      end
      @level_editor[:drag_start] = nil
      @level_editor[:last_painted_cell] = nil
    end
  end

  def mouse_left_down? mouse
    mouse.key_down.left || mouse.down
  end

  def mouse_left_held? mouse
    mouse.key_held.left || mouse.held
  end

  def mouse_left_up? mouse
    mouse.key_up.left || mouse.up
  end

  def mouse_right_down? mouse
    mouse.key_down.right || mouse.right
  end

  def editor_mouse_cell mouse
    point = @level_editor[:camera].world_point(mouse)
    col = (point[:x] / MAP_TILE).floor
    row = (point[:y] / MAP_TILE).floor
    return nil if col < 0 || row < 0
    return nil if col >= current_room.world_w / MAP_TILE || row >= current_room.world_h / MAP_TILE

    { "col" => col, "row" => row }
  end

  def current_editor_tool
    EDITOR_TOOLS[@level_editor[:tool_index]]
  end

  def editor_room_data
    @level_data["rooms"][@current_room_id.to_s]
  end

  def editor_rect_tool?
    tool = current_editor_tool
    tool[:rect] || tool[:gate]
  end

  def editor_paint_tool?
    tool = current_editor_tool
    tool[:rect]
  end

  def place_level_editor_at cell
    tool = current_editor_tool
    if tool[:rect]
      add_editor_rect(tool[:collection], cell["col"], cell["row"], EDITOR_RECT_SIZE, EDITOR_RECT_SIZE)
    elsif tool[:gate]
      set_editor_gate_rect(cell["col"], cell["row"], default_editor_gate_w(tool), default_editor_gate_h(tool), tool)
    elsif tool[:object]
      place_editor_object(tool[:key], cell["col"], cell["row"])
    elsif tool[:enemy]
      place_editor_enemy(cell["col"], cell["row"])
    end
    @level_editor[:last_painted_cell] = cell
    commit_level_editor_change
  end

  def place_level_editor_rect start_cell, end_cell
    rect = editor_rect_from_cells(start_cell, end_cell)
    tool = current_editor_tool
    if tool[:rect]
      add_editor_rect(tool[:collection], rect["col"], rect["row"], rect["w_cols"], rect["h_rows"])
    elsif tool[:gate]
      set_editor_gate_rect(rect["col"], rect["row"], rect["w_cols"], rect["h_rows"], tool)
    end
    commit_level_editor_change
  end

  def editor_rect_from_cells start_cell, end_cell
    min_col = [start_cell["col"], end_cell["col"]].min
    max_col = [start_cell["col"], end_cell["col"]].max
    min_row = [start_cell["row"], end_cell["row"]].min
    max_row = [start_cell["row"], end_cell["row"]].max
    { "col" => min_col, "row" => min_row, "w_cols" => max_col - min_col + 1, "h_rows" => max_row - min_row + 1 }
  end

  def add_editor_rect collection, col, row, w_cols, h_rows
    records = editor_room_data[collection] ||= []
    record = { "col" => col, "row" => row, "w_cols" => w_cols, "h_rows" => h_rows }
    records << record unless records.any? { |existing| same_grid_rect?(existing, record) }
  end

  def set_editor_gate_rect col, row, w_cols, h_rows, tool
    gate = editor_gate_record(tool)
    gate["rect"] = { "col" => col, "row" => row, "w_cols" => w_cols, "h_rows" => h_rows }
    gate["sprite_rect"] = editor_gate_sprite_rect(gate["rect"], tool)
    apply_editor_gate_sprite!(gate, tool)
  end

  def default_editor_gate_w tool
    2
  end

  def default_editor_gate_h tool
    tool[:final_gate] ? 10 : 3
  end

  def editor_gate_sprite_rect rect, tool
    return rect.dup unless tool[:final_gate]
    return rect.dup unless rect["w_cols"] == default_editor_gate_w(tool) && rect["h_rows"] == default_editor_gate_h(tool)

    rect.merge("col" => rect["col"] - 1, "w_cols" => 4)
  end

  def editor_gate_record tool
    gates = editor_room_data["locked_gates"] ||= []
    gate_id = tool[:final_gate] ? "#{@current_room_id}_final" : @current_room_id.to_s
    existing = if tool[:final_gate]
                 gates.find { |gate| gate["path"] == FINAL_LOCKED_GATE_SPRITE_PATH }
               else
                 gates.find { |gate| gate["path"] == LOCKED_GATE_SPRITE_PATH }
               end
    existing || gates.find { |gate| gate["id"] == gate_id } || begin
      record = {
        "id" => gate_id,
        "rect" => { "col" => 0, "row" => 0, "w_cols" => default_editor_gate_w(tool), "h_rows" => default_editor_gate_h(tool) },
        "sprite_rect" => editor_gate_sprite_rect({ "col" => 0, "row" => 0, "w_cols" => default_editor_gate_w(tool), "h_rows" => default_editor_gate_h(tool) }, tool)
      }
      apply_editor_gate_sprite!(record, tool)
      gates << record
      record
    end
  end

  def apply_editor_gate_sprite! gate, tool
    if tool[:final_gate]
      gate["path"] = FINAL_LOCKED_GATE_SPRITE_PATH
      gate["frame_w"] = FINAL_LOCKED_GATE_FRAME_W
      gate["frame_h"] = FINAL_LOCKED_GATE_FRAME_H
    else
      gate["path"] = LOCKED_GATE_SPRITE_PATH
      gate["frame_w"] = LOCKED_GATE_FRAME_W
      gate["frame_h"] = LOCKED_GATE_FRAME_H
    end
  end

  def place_editor_object type, col, row
    objects = editor_room_data["objects"] ||= []
    existing = nearest_editor_object(objects, type, col, row)
    record = existing || new_editor_object(type, col, row)
    record["col"] = col
    record["row"] = row
    objects << record unless existing
  end

  def nearest_editor_object objects, type, col, row
    candidates = objects.find_all { |record| record["type"] == type }
    return nil if candidates.empty?
    return nearest_editor_exit(candidates, col, row) if type == "exit"
    return candidates.first if unique_editor_object_type?(type)

    candidates.find { |record| record["col"].to_i == col && record["row"].to_i == row }
  end

  def nearest_editor_exit exits, col, row
    canonical = canonical_editor_exit(col)
    return exits.find { |record| record["id"] == canonical["id"] } if canonical

    exits.find do |record|
      record["col"].to_i == col && record["row"].to_i == row
    end
  end

  def unique_editor_object_type? type
    ["bell", "name_altar", "mirror", "archive_key", "final_door"].include?(type)
  end

  def new_editor_object type, col, row
    id = case type
         when "lamp" then "lamp"
         when "altar" then new_editor_altar_id(row)
         when "bell" then "#{@current_room_id}_bells"
         when "name_altar" then SANCTUM_FINAL_ALTAR_ID.to_s
         when "mirror" then "#{@current_room_id}_mirror"
         when "archive_key" then "archive_key"
         when "final_door" then "#{@current_room_id}_final_door"
         else "#{@current_room_id}_#{type}"
         end
    record = { "type" => type, "col" => col, "row" => row, "id" => id }
    if type == "exit"
      record.merge!(canonical_editor_exit(col) || default_editor_exit(col))
    end
    record
  end

  def new_editor_altar_id row
    return "#{@current_room_id}_altar" unless @current_room_id == :sanctum

    ids = SANCTUM_REGULAR_ALTAR_IDS.map(&:to_s)
    existing_ids = (editor_room_data["objects"] || []).map { |record| record["id"] }
    preferred_id = row >= 41 ? SANCTUM_REGULAR_ALTAR_IDS.first.to_s : SANCTUM_REGULAR_ALTAR_IDS.last.to_s
    return preferred_id unless existing_ids.include?(preferred_id)

    ids.find { |id| !existing_ids.include?(id) } || preferred_id
  end

  def canonical_editor_exit col
    case @current_room_id
    when :hall
      {
        "id" => "hall_to_archive",
        "target_room" => "archive",
        "target_spawn" => "from_hall",
        "return_spawn_id" => "from_archive",
        "spawn_offset_cols" => -5,
        "spawn_offset_rows" => 0,
        "unlock_altar_id" => "hall_altar"
      }
    when :archive
      if col < 65
        {
          "id" => "archive_to_hall",
          "target_room" => "hall",
          "target_spawn" => "from_archive",
          "return_spawn_id" => "from_hall",
          "spawn_offset_cols" => 5,
          "spawn_offset_rows" => 0,
          "unlock_altar_id" => nil
        }
      else
        {
          "id" => "archive_to_sanctum",
          "target_room" => "sanctum",
          "target_spawn" => "from_archive",
          "return_spawn_id" => "from_sanctum",
          "spawn_offset_cols" => -5,
          "spawn_offset_rows" => 0,
          "unlock_altar_id" => "archive_altar"
        }
      end
    when :sanctum
      {
        "id" => "sanctum_to_archive",
        "target_room" => "archive",
        "target_spawn" => "from_sanctum",
        "return_spawn_id" => "from_archive",
        "spawn_offset_cols" => 5,
        "spawn_offset_rows" => 0,
        "unlock_altar_id" => nil
      }
    else
      nil
    end
  end

  def default_editor_exit col
    {
      "target_room" => @current_room_id.to_s,
      "target_spawn" => "default",
      "return_spawn_id" => "from_#{@current_room_id}",
      "spawn_offset_cols" => col < 65 ? 5 : -5,
      "spawn_offset_rows" => 0,
      "unlock_altar_id" => nil
    }
  end

  def place_editor_enemy col, row
    spawns = @level_data["enemy_spawns"] ||= []
    existing = spawns.find { |spawn| spawn["room"] == @current_room_id.to_s }
    existing ||= { "id" => "#{@current_room_id}_enemy", "room" => @current_room_id.to_s, "runtime_id" => "#{@current_room_id}_enemy" }
    existing["col"] = col
    existing["row"] = row
    spawns << existing unless spawns.include?(existing)
  end

  def remove_level_editor_at cell
    remove_editor_rects_at(editor_room_data["barriers"] || [], cell)
    remove_editor_rects_at(editor_room_data["safe_paths"] || [], cell)
    remove_editor_objects_at(cell)
    remove_editor_gates_at(cell)
    remove_editor_enemies_at(cell)
  end

  def remove_editor_rects_at records, cell
    replacement_records = []
    records.each do |record|
      if grid_rect_contains_cell?(record, cell)
        replacement_records.concat(split_grid_rect_around_cell(record, cell))
      else
        replacement_records << record
      end
    end
    records.clear
    replacement_records.each { |record| records << record }
  end

  def remove_editor_objects_at cell
    objects = editor_room_data["objects"] || []
    objects.reject! { |record| record["col"].to_i == cell["col"] && record["row"].to_i == cell["row"] }
  end

  def remove_editor_gates_at cell
    gates = editor_room_data["locked_gates"] || []
    gates.reject! { |gate| gate["rect"] && grid_rect_contains_cell?(gate["rect"], cell) }
  end

  def remove_editor_enemies_at cell
    spawns = @level_data["enemy_spawns"] || []
    spawns.reject! do |spawn|
      spawn["room"] == @current_room_id.to_s &&
        spawn["col"].to_i == cell["col"] &&
        spawn["row"].to_i == cell["row"]
    end
  end

  def grid_rect_contains_cell? rect, cell
    cell["col"] >= rect["col"].to_i &&
      cell["col"] < rect["col"].to_i + rect["w_cols"].to_i &&
      cell["row"] >= rect["row"].to_i &&
      cell["row"] < rect["row"].to_i + rect["h_rows"].to_i
  end

  def split_grid_rect_around_cell rect, cell
    col = rect["col"].to_i
    row = rect["row"].to_i
    w_cols = rect["w_cols"].to_i
    h_rows = rect["h_rows"].to_i
    cell_col = cell["col"].to_i
    cell_row = cell["row"].to_i
    pieces = [
      { "col" => col, "row" => row, "w_cols" => w_cols, "h_rows" => cell_row - row },
      { "col" => col, "row" => cell_row + 1, "w_cols" => w_cols, "h_rows" => row + h_rows - cell_row - 1 },
      { "col" => col, "row" => cell_row, "w_cols" => cell_col - col, "h_rows" => 1 },
      { "col" => cell_col + 1, "row" => cell_row, "w_cols" => col + w_cols - cell_col - 1, "h_rows" => 1 }
    ]
    pieces.find_all { |piece| valid_grid_rect?(piece) }
  end

  def valid_grid_rect? rect
    rect["w_cols"].to_i > 0 && rect["h_rows"].to_i > 0
  end

  def same_grid_rect? first, second
    first["col"] == second["col"] &&
      first["row"] == second["row"] &&
      first["w_cols"] == second["w_cols"] &&
      first["h_rows"] == second["h_rows"]
  end

  def commit_level_editor_change
    save_level_data
    reload_rooms_from_level_data
    reload_existing_enemies_from_level_data
    reset_key_gate_states
    apply_level_runtime_state
  end

  def save_level_data
    LevelData.write(@level_data)
  end

  def apply_level_runtime_state
    close_altar
    all_interactables.each do |interactable|
      interactable.sacrifice! if sacrificed_object?(interactable.id)
      interactable.sacrifice! if interactable.word && word_sacrificed?(interactable.word)
      interactable.unlock! if interactable.is_a?(Exit) && sacrificed_object?(interactable.unlock_altar_id)
    end
  end

  def reload_existing_enemies_from_level_data
    @enemies.each do |enemy|
      spawn_id = if enemy.id == :archive_bell_sacrifice
                   "archive_bell_sacrifice"
                 elsif enemy.room_id == :sanctum
                   "sanctum_key_sacrifice"
                 else
                   "archive_primary"
                 end
      spawn = enemy_spawn(spawn_id)
      enemy.reset!(enemy.room_id, spawn)
    end
  end

  def render_level_editor args
    return unless level_editor_active?

    saved_camera = @camera
    @camera = @level_editor[:camera]
    args.outputs.sprites << Render.fullscreen(:void)
    render_floor(args)
    render_room_barriers(args)
    render_level_editor_safe_paths(args)
    interactables.each { |interactable| render_interactable(args, interactable, args.outputs) }
    current_enemies.each { |enemy| enemy.render(args, args.outputs, @camera) }
    render_level_editor_enemy_spawns(args)
    render_level_editor_grid(args)
    render_level_editor_cursor(args)
    render_level_editor_ui(args)
    @camera = saved_camera
  end

  def render_level_editor_safe_paths args
    return if current_room.safe_paths.empty?

    render_env_tiles(
      args.outputs,
      env_tile_layer(current_room.safe_paths.flat_map { |path| rect_fill_cells(path) }.uniq),
      alpha: 95
    )
  end

  def render_level_editor_grid args
    visible = {
      x: @camera.x,
      y: @camera.y,
      w: @camera.visible_w,
      h: @camera.visible_h
    }
    min_col = (visible[:x] / MAP_TILE).floor
    max_col = ((visible[:x] + visible[:w]) / MAP_TILE).ceil
    min_row = (visible[:y] / MAP_TILE).floor
    max_row = ((visible[:y] + visible[:h]) / MAP_TILE).ceil
    color = Render.color(:ash)
    (min_col..max_col).each do |col|
      x = @camera.screen_point(x: col * MAP_TILE, y: 0)[:x]
      args.outputs.lines << { x: x, y: 0, x2: x, y2: Grid.h, **color, a: 45 }
    end
    (min_row..max_row).each do |row|
      y = @camera.screen_point(x: 0, y: row * MAP_TILE)[:y]
      args.outputs.lines << { x: 0, y: y, x2: Grid.w, y2: y, **color, a: 45 }
    end
  end

  def render_level_editor_enemy_spawns args
    color = Render.color(:ember)
    (@level_data["enemy_spawns"] || []).each do |spawn|
      next unless spawn["room"] == @current_room_id.to_s

      center = @camera.screen_point(x: spawn["col"].to_i * MAP_TILE, y: spawn["row"].to_i * MAP_TILE)
      size = 22
      args.outputs.borders << {
        x: center[:x] - size / 2,
        y: center[:y] - size / 2,
        w: size,
        h: size,
        **color,
        a: 230
      }
      args.outputs.lines << { x: center[:x] - size, y: center[:y], x2: center[:x] + size, y2: center[:y], **color, a: 180 }
      args.outputs.lines << { x: center[:x], y: center[:y] - size, x2: center[:x], y2: center[:y] + size, **color, a: 180 }
    end
  end

  def render_level_editor_cursor args
    cell = editor_mouse_cell(args.inputs.mouse)
    return unless cell

    rect = @camera.screen_rect(
      x: cell["col"] * MAP_TILE,
      y: cell["row"] * MAP_TILE,
      w: MAP_TILE,
      h: MAP_TILE
    )
    args.outputs.borders << rect.merge(**Render.color(:ember), a: 230)
  end

  def render_level_editor_ui args
    tool = current_editor_tool
    panel = { x: 12, y: 608, w: 640, h: 96 }
    args.outputs.sprites << Render.solid(panel, :void, a: 210)
    args.outputs.borders << panel.merge(**Render.color(:brass), a: 180)
    args.outputs.labels << Render.label(28, 682, "LEVEL EDITOR", :ember, size_enum: 1)
    args.outputs.labels << Render.label(28, 654, "#{@current_room_id} / #{tool[:label]}", :ash, size_enum: 0)
    args.outputs.labels << Render.label(28, 628, "[ ] tool  1-0 select  Left place/paint  Shift+drag rect  Right remove  L save+return", :ash, size_enum: -2)
  end
end
