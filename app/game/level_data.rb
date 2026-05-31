module LevelData
  PATH = "data/level.json"

  def self.load_or_create
    data = DR.read_file(PATH) ? DR.parse_json_file(PATH) : nil
    return data if data && data["rooms"]

    data = default_level
    write(data)
    data
  end

  def self.write data
    DR.write_file(PATH, serialize_json(compact_level(data)))
  end

  def self.compact_level data
    rooms = data["rooms"] || {}
    rooms.each_value do |room|
      room["barriers"] = compact_rects(room["barriers"] || [])
      room["safe_paths"] = compact_rects(room["safe_paths"] || [])
    end
    data
  end

  def self.compact_rects records
    pending = rect_cells(records)
    compacted = []

    until pending.empty?
      col, row = first_compact_cell(pending)
      width = compact_rect_width(pending, col, row)
      height = compact_rect_height(pending, col, row, width)
      compacted << rect(col, row, width, height)

      (col...(col + width)).each do |x|
        (row...(row + height)).each do |y|
          pending.delete([x, y])
        end
      end
    end

    compacted.sort { |a, b| compare_rects(a, b) }
  end

  def self.first_compact_cell pending
    best = nil
    pending.each_key do |cell|
      best = cell if !best || cell[1] < best[1] || (cell[1] == best[1] && cell[0] < best[0])
    end
    best
  end

  def self.compare_rects a, b
    row_cmp = a["row"] <=> b["row"]
    return row_cmp unless row_cmp == 0

    col_cmp = a["col"] <=> b["col"]
    return col_cmp unless col_cmp == 0

    h_cmp = a["h_rows"] <=> b["h_rows"]
    return h_cmp unless h_cmp == 0

    a["w_cols"] <=> b["w_cols"]
  end

  def self.rect_cells records
    cells = {}
    records.each do |record|
      col = record["col"].to_i
      row = record["row"].to_i
      w_cols = record["w_cols"].to_i
      h_rows = record["h_rows"].to_i
      next if w_cols <= 0 || h_rows <= 0

      (col...(col + w_cols)).each do |x|
        (row...(row + h_rows)).each do |y|
          cells[[x, y]] = true
        end
      end
    end
    cells
  end

  def self.compact_rect_width pending, col, row
    width = 0
    width += 1 while pending[[col + width, row]]
    width
  end

  def self.compact_rect_height pending, col, row, width
    height = 1
    loop do
      next_row = row + height
      full_row = (col...(col + width)).all? { |x| pending[[x, next_row]] }
      break unless full_row

      height += 1
    end
    height
  end

  def self.serialize_json value, indent = 0
    case value
    when Hash
      return "{}" if value.empty?

      inner = value.map do |key, child|
        "#{" " * (indent + 2)}#{serialize_json(key.to_s)}: #{serialize_json(child, indent + 2)}"
      end
      "{\n#{inner.join(",\n")}\n#{" " * indent}}"
    when Array
      return "[]" if value.empty?

      inner = value.map { |child| "#{" " * (indent + 2)}#{serialize_json(child, indent + 2)}" }
      "[\n#{inner.join(",\n")}\n#{" " * indent}]"
    when String
      "\"#{escape_json_string(value)}\""
    when Symbol
      serialize_json(value.to_s)
    when Numeric
      value.to_s
    when true
      "true"
    when false
      "false"
    when nil
      "null"
    else
      serialize_json(value.to_s)
    end
  end

  def self.escape_json_string value
    value.to_s
         .gsub("\\", "\\\\\\\\")
         .gsub("\"", "\\\\\"")
         .gsub("\n", "\\n")
         .gsub("\r", "\\r")
         .gsub("\t", "\\t")
  end

  def self.default_level
    {
      "schema" => 1,
      "tile_size" => 128,
      "rooms" => {
        "hall" => {
          "world" => { "cols" => 130, "rows" => 82 },
          "play_area" => rect(3, 3, 124, 76),
          "objects" => [
            object("bell", 14, 40, "hall_bells"),
            object("lamp", 18, 36, "lamp"),
            object("lamp", 10, 33, "lamp"),
            object("lamp", 120, 33, "lamp"),
            object("lamp", 10, 10, "lamp"),
            object("lamp", 120, 72, "lamp"),
            object("lamp", 65, 55, "lamp"),
            object("altar", 65, 36, "hall_altar"),
            exit_object(122, 41, "hall_to_archive", "archive", "from_hall", "from_archive", -5, 0, "hall_altar")
          ],
          "barriers" => perimeter_barriers + [
            rect(5, 32, 20, 2),
            rect(5, 46, 20, 2),
            rect(5, 32, 2, 16),
            rect(25, 32, 2, 5),
            rect(25, 43, 2, 5)
          ],
          "safe_paths" => [],
          "locked_gates" => []
        },
        "archive" => {
          "world" => { "cols" => 130, "rows" => 82 },
          "play_area" => rect(3, 3, 124, 76),
          "objects" => [
            object("lamp", 16, 55, "lamp"),
            object("lamp", 65, 24, "lamp"),
            object("lamp", 36, 56, "lamp"),
            object("lamp", 55, 42, "lamp"),
            object("lamp", 69, 31, "lamp"),
            object("lamp", 86, 45, "lamp"),
            object("lamp", 57, 67, "lamp"),
            object("mirror", 17, 49, "archive_mirror"),
            object("altar", 22, 36, "archive_altar"),
            object("archive_key", 72, 70, "archive_key"),
            exit_object(8, 41, "archive_to_hall", "hall", "from_archive", "from_hall", 5, 0),
            exit_object(122, 41, "archive_to_sanctum", "sanctum", "from_archive", "from_sanctum", -5, 0, "archive_altar")
          ],
          "barriers" => perimeter_barriers + [
            rect(78, 34, 2, 16),
            rect(78, 53, 2, 19)
          ],
          "safe_paths" => archive_safe_paths,
          "locked_gates" => [
            {
              "id" => "archive",
              "rect" => rect(78, 50, 2, 3),
              "sprite_rect" => rect(78, 50, 2, 3),
              "path" => "sprites/locked_gate.png",
              "frame_w" => 512,
              "frame_h" => 768
            }
          ]
        },
        "sanctum" => {
          "world" => { "cols" => 130, "rows" => 82 },
          "play_area" => rect(3, 3, 124, 76),
          "objects" => [
            object("lamp", 18, 55, "lamp"),
            object("lamp", 110, 58, "lamp"),
            object("altar", 85, 53, "sanctum_key_altar"),
            object("altar", 85, 30, "sanctum_memory_altar"),
            object("name_altar", 100, 41, "sanctum_name_altar"),
            object("final_door", 120, 41, "sanctum_final_door"),
            exit_object(8, 41, "sanctum_to_archive", "archive", "from_sanctum", "from_archive", 5, 0)
          ],
          "barriers" => perimeter_barriers + [
            rect(63, 3, 4, 11),
            rect(63, 24, 4, 12),
            rect(63, 46, 4, 12),
            rect(63, 58, 4, 21),
            rect(20, 3, 2, 9),
            rect(20, 20, 2, 2),
            rect(20, 30, 2, 2),
            rect(20, 36, 2, 2),
            rect(20, 46, 2, 33),
            rect(20, 36, 43, 2),
            rect(20, 46, 44, 2),
            rect(28, 12, 2, 24),
            rect(36, 3, 2, 21),
            rect(44, 12, 2, 24),
            rect(52, 3, 2, 21),
            rect(60, 24, 2, 12)
          ],
          "safe_paths" => [],
          "locked_gates" => [
            {
              "id" => "sanctum",
              "rect" => rect(64, 36, 2, 10),
              "sprite_rect" => rect(63, 36, 4, 10),
              "path" => "sprites/locked_gate_final.png",
              "frame_w" => 512,
              "frame_h" => 1280
            }
          ]
        }
      },
      "enemy_spawns" => [
        { "id" => "archive_primary", "room" => "archive", "col" => 65, "row" => 41, "runtime_id" => nil },
        { "id" => "archive_bell_sacrifice", "room" => "archive", "col" => 112, "row" => 62, "runtime_id" => "archive_bell_sacrifice" },
        { "id" => "sanctum_key_sacrifice", "room" => "sanctum", "col" => 38, "row" => 54, "runtime_id" => "sanctum_key_sacrifice" }
      ]
    }
  end

  def self.object type, col, row, id
    { "type" => type, "col" => col, "row" => row, "id" => id }
  end

  def self.exit_object col, row, id, target_room, target_spawn, return_spawn_id, spawn_offset_cols, spawn_offset_rows, unlock_altar_id = nil
    object("exit", col, row, id).merge(
      "target_room" => target_room,
      "target_spawn" => target_spawn,
      "return_spawn_id" => return_spawn_id,
      "spawn_offset_cols" => spawn_offset_cols,
      "spawn_offset_rows" => spawn_offset_rows,
      "unlock_altar_id" => unlock_altar_id
    )
  end

  def self.rect col, row, w_cols, h_rows
    { "col" => col, "row" => row, "w_cols" => w_cols, "h_rows" => h_rows }
  end

  def self.perimeter_barriers
    cells = []
    (3..126).each do |col|
      cells << rect(col, 3, 1, 1)
      cells << rect(col, 78, 1, 1)
    end
    (4..77).each do |row|
      cells << rect(3, row, 1, 1)
      cells << rect(126, row, 1, 1)
    end
    cells
  end

  def self.archive_safe_paths
    [
      rect(5, 33, 19, 17),
      rect(14, 38, 15, 7),
      rect(29, 38, 6, 21),
      rect(29, 53, 23, 7),
      rect(49, 33, 6, 27),
      rect(49, 33, 14, 7),
      rect(60, 17, 6, 23),
      rect(60, 17, 18, 7),
      rect(74, 17, 6, 15),
      rect(74, 25, 18, 7),
      rect(88, 14, 6, 18),
      rect(88, 14, 28, 7),
      rect(112, 14, 6, 30),
      rect(100, 36, 25, 8),
      rect(54, 53, 6, 15),
      rect(54, 62, 22, 7),
      rect(72, 50, 6, 19),
      rect(78, 50, 6, 3),
      rect(80, 48, 24, 7),
      rect(100, 36, 6, 19)
    ]
  end
end
