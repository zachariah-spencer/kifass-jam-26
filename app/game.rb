class Room
  attr_reader :id, :world_w, :world_h, :play_area, :player_spawns, :interactables, :barriers

  def initialize id, world_w, world_h, play_area, player_spawns, interactables, barriers = []
    @id = id
    @world_w = world_w
    @world_h = world_h
    @play_area = play_area
    @player_spawns = player_spawns
    @interactables = interactables
    @barriers = barriers
  end

  def spawn spawn_id
    @player_spawns[spawn_id] || @player_spawns[:default]
  end
end

class Game
  VIEWPORT_W = 1280
  VIEWPORT_H = 720
  WORLD_W = 2200
  WORLD_H = 1400
  PLAY_AREA = { x: 52, y: 58, w: WORLD_W - 104, h: WORLD_H - 116 }
  MESSAGE_DELAY_FRAMES = 3.seconds
  MESSAGE_CHARACTER_INTERVAL = 0.1.seconds
  SACRIFICE_SCRAMBLE_INTERVAL = 0.08.seconds
  SACRIFICE_SCRAMBLE_SYMBOLS = "!@#$%^&*?+=~[]{}/\\"
  ALTAR_PANEL = { x: 430, y: 190, w: 420, h: 330 }
  ALTAR_WORD_ROW_H = 42
  ROOM_FADE_OUT_FRAMES = 8
  ROOM_FADE_IN_FRAMES = 8
  INTERACTION_RADIUS = 128
  ARCHIVE_SAFE_PATH_TOLERANCE = 18
  ARCHIVE_SAFE_PATH_EXTRA_WIDTH = 56
  BELL_STUN_FRAMES = 3.seconds
  BELL_TOOLTIP_TEXT = "Press E or click empty space to ring the bell and stun the Nameless Thing."
  HALL_BELL_GATE = { x: 416, y: 616, w: 32, h: 64 }
  SANCTUM_WALL_X = WORLD_W / 2 - 16
  SANCTUM_GATE_H = 170
  SANCTUM_KEY_GATE = { x: SANCTUM_WALL_X, y: WORLD_H / 2 - SANCTUM_GATE_H / 2, w: 32, h: SANCTUM_GATE_H }
  SANCTUM_REGULAR_ALTAR_IDS = [:sanctum_key_altar, :sanctum_memory_altar]
  SANCTUM_FINAL_ALTAR_ID = :sanctum_name_altar
  SANCTUM_ALTAR_WORDS = ["KEY", "BELL", "MIRROR"]
  PLAYER_NAME_WORD = "YOUR NAME"

  attr_reader :player, :camera, :learned_words, :sacrificed_words, :sacrificed_object_ids, :current_room_id, :enemy

  def initialize
    restart
  end

  def restart
    @rooms = build_rooms
    @current_room_id = :hall
    room = current_room
    spawn = room.spawn(:default)
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @player = Player.new(spawn[:x], spawn[:y])
    @enemy = NamelessThing.new(:archive, archive_enemy_spawn[:x], archive_enemy_spawn[:y])
    @learned_words = []
    @learned_object_ids = []
    @learned_word_sources = {}
    @sacrificed_words = []
    @sacrificed_object_ids = []
    @altar_open = false
    @active_altar = nil
    @room_transition = nil
    @archive_reset_spawn_id = :from_hall
    @camera.snap_to(@player)
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
    @bell_tooltip_shown = false
    @bell_tooltip_until = nil
    @ending_sequence_triggered = false
  end

  def build_rooms
    {
      hall: build_hall_room,
      archive: build_archive_room,
      sanctum: build_sanctum_room
    }
  end

  def build_hall_room
    Room.new(
      :hall,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: WORLD_W / 2 - Player::SIZE / 2, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_archive: { x: WORLD_W - 246, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Bell.new(250, 650, :hall_bells),
        Lamp.new(164, 552, :lamp),
        Lamp.new(WORLD_W - 192, 552, :lamp),
        Lamp.new(164, 132, :lamp),
        Lamp.new(WORLD_W - 192, WORLD_H - 188, :lamp),
        Lamp.new(WORLD_W / 2 - Lamp::SIZE / 2, WORLD_H / 2 + 180, :lamp),
        Altar.new(WORLD_W / 2 - Altar::W / 2, WORLD_H / 2 - 132, :hall_altar),
        Exit.new(WORLD_W - 166, WORLD_H / 2 - Exit::H / 2, :hall_to_archive, :archive, :from_hall, unlock_altar_id: :hall_altar)
      ],
      hall_bell_alcove_walls
    )
  end

  def hall_bell_alcove_walls
    [
      { x: 88, y: 520, w: 360, h: 32 },
      { x: 88, y: 800, w: 360, h: 32 },
      { x: 88, y: 520, w: 32, h: 312 },
      { x: 416, y: 520, w: 32, h: 96 },
      { x: 416, y: 680, w: 32, h: 152 }
    ]
  end

  def build_archive_room
    Room.new(
      :archive,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: 220, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_hall: { x: 220, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_sanctum: { x: WORLD_W - 246, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Lamp.new(260, WORLD_H / 2 + 180, :lamp),
        Lamp.new(WORLD_W / 2 - Lamp::SIZE / 2, WORLD_H / 2 - 220, :lamp),
        Lamp.new(610, 928, :lamp),
        Lamp.new(930, 622, :lamp),
        Lamp.new(1180, 436, :lamp),
        Lamp.new(1468, 682, :lamp),
        Lamp.new(970, 1070, :lamp),
        Mirror.new(286, WORLD_H / 2 + 110, :archive_mirror),
        Altar.new(374, WORLD_H / 2 - 90, :archive_altar),
        ArchiveKey.new(1234, WORLD_H / 2 + 372, :archive_key),
        Exit.new(96, WORLD_H / 2 - Exit::H / 2, :archive_to_hall, :hall, :from_archive),
        Exit.new(WORLD_W - 166, WORLD_H / 2 - Exit::H / 2, :archive_to_sanctum, :sanctum, :from_archive, unlock_altar_id: :archive_altar)
      ]
    )
  end

  def build_sanctum_room
    Room.new(
      :sanctum,
      WORLD_W,
      WORLD_H,
      PLAY_AREA,
      {
        default: { x: 220, y: WORLD_H / 2 - Player::SIZE / 2 },
        from_archive: { x: 220, y: WORLD_H / 2 - Player::SIZE / 2 }
      },
      [
        Lamp.new(300, WORLD_H / 2 + 178, :lamp),
        Lamp.new(WORLD_W - 360, WORLD_H / 2 + 236, :lamp),
        Altar.new(WORLD_W / 2 + 246, WORLD_H / 2 + 150, :sanctum_key_altar),
        Altar.new(WORLD_W / 2 + 246, WORLD_H / 2 - 214, :sanctum_memory_altar),
        NameAltar.new(WORLD_W - 500, WORLD_H / 2 - NameAltar::H / 2, SANCTUM_FINAL_ALTAR_ID),
        FinalDoor.new(WORLD_W - 188, WORLD_H / 2 - FinalDoor::H / 2, :sanctum_final_door),
        Exit.new(96, WORLD_H / 2 - Exit::H / 2, :sanctum_to_archive, :archive, :from_sanctum)
      ],
      sanctum_walls
    )
  end

  def sanctum_walls
    [
      { x: SANCTUM_WALL_X, y: PLAY_AREA[:y], w: 32, h: SANCTUM_KEY_GATE[:y] - PLAY_AREA[:y] },
      {
        x: SANCTUM_WALL_X,
        y: SANCTUM_KEY_GATE[:y] + SANCTUM_KEY_GATE[:h],
        w: 32,
        h: PLAY_AREA[:y] + PLAY_AREA[:h] - (SANCTUM_KEY_GATE[:y] + SANCTUM_KEY_GATE[:h])
      }
    ]
  end

  def current_room
    @rooms[@current_room_id]
  end

  def interactables
    current_room.interactables
  end

  def update args
    update_room_transition
    return if room_transition_active?

    handle_interaction(args)
    update_interaction_text
    interactables.each { |interactable| interactable.update(args) }
    @player.update(args, current_room.play_area, active_barriers)
    close_altar_if_player_left_range
    return if reset_player_if_off_archive_path

    return if update_enemy(args)

    @camera.follow(@player)
    handle_exit_transition
  end

  def handle_interaction args
    click = args.inputs.mouse.click
    return handle_altar_selection(click) if @altar_open && click
    return if @altar_open

    interactable = nil
    if click
      world_click = @camera.world_point(click)
      interactable = nearby_interactables.find { |candidate| candidate.contains_point?(world_click) }
      if interactable
        set_interaction_text(interactable.interact(self))
        return
      end
    end

    ring_bell if bell_input?(args, click)
    set_interaction_text(nil) if click && !bell_input?(args, click)
  end

  def request_room_transition target_room_id, target_spawn_id, source_exit = nil
    return "The way is lost." unless @rooms[target_room_id]
    return nil if room_transition_active?

    @room_transition = {
      target_room_id: target_room_id,
      target_spawn_id: target_spawn_id,
      source_room_id: @current_room_id,
      source_exit: source_exit,
      started_at: Kernel.tick_count,
      phase: :fade_out
    }
    close_altar
    clear_interaction_text
    nil
  end

  def room_transition_active?
    !!@room_transition
  end

  def update_room_transition
    return unless @room_transition

    elapsed = Kernel.tick_count - @room_transition[:started_at]
    if @room_transition[:phase] == :fade_out && elapsed >= ROOM_FADE_OUT_FRAMES
      enter_room(@room_transition[:target_room_id], @room_transition[:target_spawn_id])
      @room_transition[:phase] = :fade_in
      @room_transition[:started_at] = Kernel.tick_count
    elsif @room_transition[:phase] == :fade_in && elapsed >= ROOM_FADE_IN_FRAMES
      @room_transition = nil
    end
  end

  def enter_room room_id, spawn_id
    @current_room_id = room_id
    room = current_room
    @archive_reset_spawn_id = archive_reset_spawn_for(spawn_id) if room_id == :archive
    spawn = room.spawn(spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @enemy.reset!(:archive, archive_enemy_spawn) if room_id == :archive
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @camera.snap_to(@player)
  end

  def update_enemy args
    return false unless @current_room_id == :archive
    return false unless @enemy.room_id == @current_room_id

    @enemy.update(args, @player, current_room, enemy_patrol_points(current_room), word_sacrificed?("BELL"))

    if @enemy.room_id == @current_room_id && rects_intersect?(@enemy.rect, @player.rect)
      restart
      return true
    end

    false
  end

  def exits
    interactables.find_all { |interactable| interactable.is_a?(Exit) }
  end

  def traversable_exits
    exits.find_all { |exit| exit.can_traverse? }
  end

  def active_barriers
    barriers = current_room.barriers.dup
    barriers << HALL_BELL_GATE if current_room.id == :hall && !knows_word?("KEY")
    barriers << SANCTUM_KEY_GATE if current_room.id == :sanctum && !knows_word?("KEY")
    barriers
  end

  def knows_word? word
    @learned_words.include?(word)
  end

  def word_sacrificed? word
    @sacrificed_words.include?(word)
  end

  def ending_sequence_triggered?
    @ending_sequence_triggered
  end

  def bell_input? args, click
    return false unless knows_word?("BELL")
    return false if word_sacrificed?("BELL")

    args.inputs.keyboard.key_down.e || !!click
  end

  def ring_bell
    @enemy.stun!(BELL_STUN_FRAMES)
  end

  def nearby_interactables
    interactables.find_all { |interactable| nearby_interactable?(interactable) }
  end

  def nearby_interactable? interactable
    distance_between(@player.center, interactable.center) <= INTERACTION_RADIUS
  end

  def enemy_patrol_points room
    return archive_enemy_patrol_points if room.id == :archive

    room_exits = traversable_exits
    return [{ x: room.play_area[:x] + room.play_area[:w] / 2, y: room.play_area[:y] + room.play_area[:h] / 2 }] if room_exits.empty?

    room_exits.map do |exit|
      {
        x: (exit.center[:x] + room.world_w / 2) / 2,
        y: exit.center[:y]
      }
    end
  end

  def archive_enemy_patrol_points
    [
      { x: WORLD_W / 2, y: WORLD_H / 2 + 250 },
      { x: WORLD_W - 312, y: WORLD_H / 2 },
      { x: WORLD_W / 2, y: WORLD_H / 2 - 230 },
      { x: 320, y: WORLD_H / 2 }
    ]
  end

  def archive_enemy_spawn
    {
      x: WORLD_W / 2 - NamelessThing::SIZE / 2,
      y: WORLD_H / 2 - NamelessThing::SIZE / 2
    }
  end

  def archive_reset_spawn_for spawn_id
    spawn_id == :from_sanctum ? :from_sanctum : :from_hall
  end

  def archive_safe_paths
    raw_paths = [
      { x: 92, y: 560, w: 398, h: 280 },
      { x: 250, y: 650, w: 340, h: 100 },
      { x: 500, y: 650, w: 100, h: 350 },
      { x: 500, y: 900, w: 440, h: 100 },
      { x: 840, y: 560, w: 100, h: 440 },
      { x: 840, y: 560, w: 380, h: 100 },
      { x: 1120, y: 360, w: 100, h: 300 },
      { x: 1120, y: 360, w: 380, h: 100 },
      { x: 1400, y: 360, w: 100, h: 350 },
      { x: 1400, y: 610, w: 380, h: 100 },
      { x: 1700, y: 610, w: 408, h: 120 },
      { x: 920, y: 900, w: 100, h: 230 },
      { x: 920, y: 1030, w: 380, h: 100 }
    ]

    raw_paths.map { |path| expanded_archive_safe_path(path) }
  end

  def expanded_archive_safe_path path
    {
      x: path[:x] - ARCHIVE_SAFE_PATH_EXTRA_WIDTH / 2,
      y: path[:y] - ARCHIVE_SAFE_PATH_EXTRA_WIDTH / 2,
      w: path[:w] + ARCHIVE_SAFE_PATH_EXTRA_WIDTH,
      h: path[:h] + ARCHIVE_SAFE_PATH_EXTRA_WIDTH
    }
  end

  def reset_player_if_off_archive_path
    return false unless @current_room_id == :archive
    return false if point_on_archive_safe_path?(@player.center)

    spawn = current_room.spawn(@archive_reset_spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.stop!
    close_altar
    set_interaction_text("The floor forgets your step.")
    @camera.snap_to(@player)
    true
  end

  def point_on_archive_safe_path? point
    archive_safe_paths.any? do |path|
      point_inside_rect?(
        point,
        {
          x: path[:x] - ARCHIVE_SAFE_PATH_TOLERANCE,
          y: path[:y] - ARCHIVE_SAFE_PATH_TOLERANCE,
          w: path[:w] + ARCHIVE_SAFE_PATH_TOLERANCE * 2,
          h: path[:h] + ARCHIVE_SAFE_PATH_TOLERANCE * 2
        }
      )
    end
  end

  def interaction_text_for interactable
    return nil unless interactable
    return interactable.sacrificed_interaction_text if interactable.word && @sacrificed_words.include?(interactable.word)
    return interactable.sacrificed_interaction_text if sacrificed_object?(interactable.id)
    return interactable.interaction_text unless interactable.word
    return interactable.interaction_text if @learned_object_ids.include?(interactable.id)

    unless @learned_words.include?(interactable.word)
      @learned_words << interactable.word 
      @player.light_size = 2048 if interactable.id == :lamp
      show_bell_tooltip if interactable.word == "BELL"
    end
    @learned_object_ids << interactable.id
    @learned_word_sources[interactable.word] = interactable.id
    "#{interactable.interaction_text} You remember that this is a #{interactable.word}."
  end

  def open_altar altar
    return "The altar is spent." if altar.sacrificed?

    @active_altar = altar
    @altar_open = true
    sacrificeable_words.empty? ? "The altar waits for a name." : "Choose a name to sacrifice."
  end

  def handle_altar_selection click
    word = altar_word_at(click)

    if word
      sacrifice_word(word)
    else
      close_altar
      set_interaction_text(nil)
    end
  end

  def sacrifice_word word
    return unless sacrificeable_words.include?(word)

    active_altar_id = @active_altar ? @active_altar.id : nil
    if word == PLAYER_NAME_WORD
      @sacrificed_words << word unless @sacrificed_words.include?(word)
      @ending_sequence_triggered = true
      @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
      @active_altar.sacrifice! if @active_altar
      close_altar
      set_interaction_text("You sacrificed #{word}.")
      return
    end

    @player.light_size = 4096 if word == "LAMP"

    @learned_words.delete(word)
    @sacrificed_words << word unless @sacrificed_words.include?(word)
    @enemy.clear_stun! if word == "BELL"

    @learned_word_sources.delete(word)
    all_interactables.each do |interactable|
      next unless interactable.word == word

      @sacrificed_object_ids << interactable.id unless @sacrificed_object_ids.include?(interactable.id)
      interactable.sacrifice!
    end

    unlock_exits_for(active_altar_id)
    @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
    @active_altar.sacrifice! if @active_altar
    close_altar
    set_interaction_text("You sacrificed #{word}.")
  end

  def show_bell_tooltip
    return if @bell_tooltip_shown

    @bell_tooltip_shown = true
    @bell_tooltip_until = Kernel.tick_count + BELL_STUN_FRAMES
  end

  def unlock_exits_for altar_id
    return unless altar_id

    all_interactables.each do |interactable|
      next unless interactable.is_a?(Exit)
      next unless interactable.unlock_altar_id == altar_id

      interactable.unlock!
    end
  end

  def sacrificeable_words
    return sanctum_name_sacrifice_words if @active_altar && @active_altar.id == SANCTUM_FINAL_ALTAR_ID
    return sanctum_regular_sacrifice_words if @active_altar && sanctum_regular_altar?(@active_altar)
    return @learned_words.select { |word| archive_sacrifice_word?(word) } if @active_altar && @active_altar.id == :archive_altar

    @learned_words
  end

  def sanctum_regular_sacrifice_words
    words = @learned_words.select { |word| SANCTUM_ALTAR_WORDS.include?(word) }
    return words.select { |word| word == "KEY" } if sanctum_regular_altar_spent_count == 1 && !word_sacrificed?("KEY")
    return words.reject { |word| word == "KEY" } if word_sacrificed?("KEY")

    words
  end

  def sanctum_name_sacrifice_words
    sanctum_final_altar_active? ? [PLAYER_NAME_WORD] : []
  end

  def sanctum_regular_altar? altar
    SANCTUM_REGULAR_ALTAR_IDS.include?(altar.id)
  end

  def sanctum_regular_altar_spent_count
    SANCTUM_REGULAR_ALTAR_IDS.count { |altar_id| sacrificed_object?(altar_id) }
  end

  def sanctum_final_altar_active?
    sanctum_regular_altar_spent_count == SANCTUM_REGULAR_ALTAR_IDS.length
  end

  def archive_sacrifice_word? word
    word == "MIRROR" || word == "KEY"
  end

  def sacrificed_object? object_id
    @sacrificed_object_ids.include?(object_id)
  end

  def all_interactables
    objects = []
    @rooms.each_value do |room|
      room.interactables.each { |interactable| objects << interactable }
    end
    objects
  end

  def close_altar
    @altar_open = false
    @active_altar = nil
  end

  def close_altar_if_player_left_range
    return unless @altar_open && @active_altar
    return if nearby_interactable?(@active_altar)

    close_altar
    clear_interaction_text
  end

  def altar_word_at point
    sacrificeable_words.each_with_index do |word, index|
      return word if point_inside_rect?(point, altar_word_rect(index))
    end

    nil
  end

  def altar_word_rect index
    {
      x: ALTAR_PANEL[:x] + 32,
      y: ALTAR_PANEL[:y] + ALTAR_PANEL[:h] - 114 - index * ALTAR_WORD_ROW_H,
      w: ALTAR_PANEL[:w] - 64,
      h: 34
    }
  end

  def point_inside_rect? point, rect
    point_x = point.is_a?(Hash) ? point[:x] : point.x
    point_y = point.is_a?(Hash) ? point[:y] : point.y
    point_x >= rect[:x] && point_x <= rect[:x] + rect[:w] && point_y >= rect[:y] && point_y <= rect[:y] + rect[:h]
  end

  def handle_exit_transition
    exit = nearby_interactables.find { |interactable| interactable.is_a?(Exit) && rects_intersect?(@player.rect, interactable.rect) }
    text = exit&.interact(self)
    set_interaction_text(text) if text && text != @interaction_text
  end

  def rects_intersect? first, second
    first[:x] < second[:x] + second[:w] &&
      first[:x] + first[:w] > second[:x] &&
      first[:y] < second[:y] + second[:h] &&
      first[:y] + first[:h] > second[:y]
  end

  def distance_between first, second
    dx = second[:x] - first[:x]
    dy = second[:y] - first[:y]
    Math.sqrt(dx * dx + dy * dy)
  end

  def set_interaction_text text
    @interaction_text = text
    @interaction_started_at = text ? Kernel.tick_count : nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = sacrificed_word_from_text(text)
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
  end

  def update_interaction_text
    return unless @interaction_text

    if visible_interaction_text.length == @interaction_text.length
      @interaction_finished_at ||= Kernel.tick_count
      clear_interaction_text if Kernel.tick_count - @interaction_finished_at >= MESSAGE_DELAY_FRAMES
    end
  end

  def clear_interaction_text
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
  end

  def visible_interaction_text
    return "" unless @interaction_text && @interaction_started_at

    elapsed = Kernel.tick_count - @interaction_started_at
    character_count = elapsed.idiv(MESSAGE_CHARACTER_INTERVAL) + 1
    current_interaction_text[0, character_count.clamp(0, @interaction_text.length)]
  end

  def current_interaction_text
    return @interaction_text unless @interaction_sacrificed_word && @interaction_finished_at

    @interaction_text.sub(@interaction_sacrificed_word, scrambled_sacrificed_word)
  end

  def scrambled_sacrificed_word
    elapsed = Kernel.tick_count - @interaction_finished_at
    @interaction_scramble_order ||= random_sacrifice_scramble_order
    scramble_count = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL).clamp(0, @interaction_scramble_order.length)
    scramble_tick = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL)
    return @interaction_scrambled_word if @interaction_scrambled_at == scramble_tick && @interaction_scrambled_word

    @interaction_scrambled_word ||= @interaction_sacrificed_word.dup
    scramble_count.times do |index|
      word_index = @interaction_scramble_order[index]
      @interaction_scrambled_word[word_index] = SACRIFICE_SCRAMBLE_SYMBOLS[rand(SACRIFICE_SCRAMBLE_SYMBOLS.length)]
    end
    @interaction_scrambled_at = scramble_tick

    @interaction_scrambled_word
  end

  def random_sacrifice_scramble_order
    order = []
    @interaction_sacrificed_word.length.times do |index|
      next if @interaction_sacrificed_word[index] == " "

      insert_at = order.length == 0 ? 0 : rand(order.length + 1)
      order.insert(insert_at, index)
    end

    order
  end

  def sacrificed_word_from_text text
    return nil unless text

    prefix = "You sacrificed "
    suffix = "."
    return nil unless text.start_with?(prefix) && text.end_with?(suffix)

    text[prefix.length, text.length - prefix.length - suffix.length]
  end

  def render args
    render_lit_scene(args)
    render_ui(args)
    render_room_transition(args)
  end

  def render_lit_scene args
    args.outputs[:scene].set(w: Grid.w, h: Grid.h, background_color: [10, 9, 14, 255])
    args.outputs[:darkness].set(w: Grid.w, h: Grid.h, background_color: [0, 0, 0, 0])

    render_floor(args, args.outputs[:scene])
    render_room_barriers(args, args.outputs[:scene])
    render_archive_safe_paths(args, args.outputs[:scene])
    interactables.each { |interactable| interactable.render(args, args.outputs[:scene], @camera) }
    nearby_interactables.each { |interactable| interactable.render_highlight(args, args.outputs[:scene], @camera) }
    @enemy.render(args, args.outputs[:scene], @camera) if @enemy.room_id == @current_room_id
    @player.render(args, args.outputs[:scene], @camera)
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    @player.render_light(args, args.outputs[:darkness], @camera)

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :scene }
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :darkness }
  end

  def render_floor args, outputs = args.outputs
    play_area = @camera.screen_rect(current_room.play_area)
    outputs.sprites << Render.solid(play_area, :stone, a: 85)
    outputs.borders << play_area.merge(**Render.color(:wall))
  end

  def render_room_barriers args, outputs = args.outputs
    current_room.barriers.each do |barrier|
      barrier_rect = @camera.screen_rect(barrier)
      outputs.sprites << Render.solid(barrier_rect, :wall, a: 245)
      outputs.borders << barrier_rect.merge(**Render.color(:stone), a: 220)
    end

    render_key_gate(HALL_BELL_GATE, outputs) if current_room.id == :hall
    render_key_gate(SANCTUM_KEY_GATE, outputs) if current_room.id == :sanctum
  end

  def render_key_gate gate, outputs
    gate_rect = @camera.screen_rect(gate)
    if knows_word?("KEY")
      outputs.borders << gate_rect.merge(**Render.color(:ember), a: 85)
      return
    end

    outputs.sprites << Render.solid(gate_rect, :void, a: 245)
    outputs.borders << gate_rect.merge(**Render.color(:brass), a: 235)
    outputs.labels << Render.label(
      gate_rect[:x] + gate_rect[:w] / 2,
      gate_rect[:y] + gate_rect[:h] / 2 + 8,
      "LOCK",
      :brass,
      size_enum: -2,
      alignment_enum: 1
    )
  end

  def render_archive_safe_paths args, outputs = args.outputs
    return unless @current_room_id == :archive
    return unless @learned_words.include?("MIRROR")
    return if @sacrificed_words.include?("MIRROR")

    archive_safe_paths.each do |path|
      path_rect = @camera.screen_rect(path)
      pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 120)
      outputs.sprites << Render.solid(path_rect, :ash, a: (28 + pulse * 8).to_i)
      outputs.borders << path_rect.merge(**Render.color(:brass), a: (55 + pulse * 18).to_i)
    end
  end

  def render_ui args
    args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    render_learned_words(args)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    render_bell_tooltip(args)
    render_altar(args) if @altar_open
    args.outputs.labels << Render.label(36, 40, "WASD / arrows move. R resets. Esc returns to title.", :ash, size_enum: -1)
  end

  def render_bell_tooltip args
    return unless @bell_tooltip_until
    return if Kernel.tick_count >= @bell_tooltip_until

    panel = { x: 286, y: 92, w: 708, h: 44 }
    args.outputs.sprites << Render.solid(panel, :void, a: 210)
    args.outputs.borders << panel.merge(**Render.color(:brass), a: 220)
    args.outputs.labels << Render.label(640, 120, BELL_TOOLTIP_TEXT, :flame, size_enum: 0, alignment_enum: 1)
  end

  def render_learned_words args
    args.outputs.labels << Render.label(1080, 694, "LEARNED", :ash, size_enum: 1)

    if @learned_words.empty?
      args.outputs.labels << Render.label(1080, 664, "none", :ash, size_enum: -1)
      return
    end

    @learned_words.each_with_index do |word, index|
      args.outputs.labels << Render.label(1080, 664 - index * 24, word, :ember, size_enum: 0)
    end
  end

  def render_altar args
    args.outputs.sprites << Render.solid({ x: 0, y: 0, w: Grid.w, h: Grid.h }, :void, a: 150)
    args.outputs.sprites << Render.solid(ALTAR_PANEL, :stone)
    args.outputs.borders << ALTAR_PANEL.merge(**Render.color(:brass))
    args.outputs.labels << Render.label(640, 478, "SACRIFICE A NAME", :ash, size_enum: 2, alignment_enum: 1)

    if sacrificeable_words.empty?
      args.outputs.labels << Render.label(640, 388, "No learned names.", :ash, size_enum: 0, alignment_enum: 1)
      args.outputs.labels << Render.label(640, 246, "Click away to close.", :ash, size_enum: -1, alignment_enum: 1)
      return
    end

    sacrificeable_words.each_with_index do |word, index|
      rect = altar_word_rect(index)
      args.outputs.sprites << Render.solid(rect, :wall)
      args.outputs.borders << rect.merge(**Render.color(:ember))
      args.outputs.labels << Render.label(rect[:x] + 18, rect[:y] + 24, word, :ember, size_enum: 0)
    end
  end

  def render_room_transition args
    return unless @room_transition

    elapsed = Kernel.tick_count - @room_transition[:started_at]
    alpha = if @room_transition[:phase] == :fade_out
              elapsed * 255 / ROOM_FADE_OUT_FRAMES
            else
              255 - elapsed * 255 / ROOM_FADE_IN_FRAMES
            end
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha.clamp(0, 255) }
  end
end
