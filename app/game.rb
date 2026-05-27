class Room
  attr_reader :id, :world_w, :world_h, :play_area, :player_spawns, :interactables

  def initialize id, world_w, world_h, play_area, player_spawns, interactables
    @id = id
    @world_w = world_w
    @world_h = world_h
    @play_area = play_area
    @player_spawns = player_spawns
    @interactables = interactables
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
    @enemy = NamelessThing.new(:archive, WORLD_W / 2 - NamelessThing::SIZE / 2, WORLD_H / 2 + 260)
    @learned_words = []
    @learned_object_ids = []
    @learned_word_sources = {}
    @sacrificed_words = []
    @sacrificed_object_ids = []
    @altar_open = false
    @active_altar = nil
    @room_transition = nil
    @pending_enemy_transition = nil
    @camera.snap_to(@player)
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
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
        Lamp.new(164, 552, :lamp),
        Lamp.new(WORLD_W - 192, 552, :lamp),
        Lamp.new(164, 132, :lamp),
        Lamp.new(WORLD_W - 192, WORLD_H - 188, :lamp),
        Lamp.new(WORLD_W / 2 - Lamp::SIZE / 2, WORLD_H / 2 + 180, :lamp),
        Altar.new(WORLD_W / 2 - Altar::W / 2, WORLD_H / 2 - 132, :hall_altar),
        Exit.new(WORLD_W - 166, WORLD_H / 2 - Exit::H / 2, :hall_to_archive, :archive, :from_hall)
      ]
    )
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
        Altar.new(WORLD_W / 2 - Altar::W / 2, WORLD_H / 2 - 24, :archive_altar),
        Exit.new(96, WORLD_H / 2 - Exit::H / 2, :archive_to_hall, :hall, :from_archive),
        Exit.new(WORLD_W - 166, WORLD_H / 2 - Exit::H / 2, :archive_to_sanctum, :sanctum, :from_archive)
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
        Lamp.new(WORLD_W / 2 - Lamp::SIZE / 2, WORLD_H / 2 + 120, :lamp),
        Altar.new(WORLD_W / 2 - Altar::W / 2, WORLD_H / 2 - 92, :sanctum_altar),
        Exit.new(96, WORLD_H / 2 - Exit::H / 2, :sanctum_to_archive, :archive, :from_sanctum)
      ]
    )
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

    update_pending_enemy_transition
    handle_interaction(args)
    update_interaction_text
    interactables.each { |interactable| interactable.update(args) }
    @player.update(args, current_room.play_area)
    return if update_enemy(args)

    @camera.follow(@player)
    handle_exit_transition
  end

  def handle_interaction args
    return unless args.inputs.mouse.click

    return handle_altar_selection(args.inputs.mouse.click) if @altar_open

    click = @camera.world_point(args.inputs.mouse.click)
    interactable = interactables.find { |candidate| candidate.contains_point?(click) }
    set_interaction_text(interactable&.interact(self))
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
    schedule_enemy_follow_transition(@room_transition[:source_room_id], @room_transition[:source_exit])
    @current_room_id = room_id
    room = current_room
    spawn = room.spawn(spawn_id)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, room.world_w, room.world_h)
    @camera.snap_to(@player)
  end

  def update_enemy args
    return unless @enemy.room_id == @current_room_id

    exit = @enemy.update(args, @player, current_room, exits, enemy_patrol_points(current_room))
    move_enemy_through_exit(exit) if exit

    if @enemy.room_id == @current_room_id && rects_intersect?(@enemy.rect, @player.rect)
      restart
      return true
    end

    false
  end

  def schedule_enemy_follow_transition source_room_id, source_exit
    return unless source_exit
    return unless @enemy.room_id == source_room_id
    return unless @enemy.state == :chase || distance_between(@enemy.center, source_exit.center) <= NamelessThing::CHASE_RADIUS

    chase_frames = (distance_between(@enemy.center, source_exit.center) / NamelessThing::CHASE_SPEED).ceil
    @pending_enemy_transition = {
      source_exit: source_exit,
      target_room_id: source_exit.target_room_id,
      target_spawn_id: source_exit.target_spawn_id,
      arrive_at: Kernel.tick_count + chase_frames
    }
  end

  def update_pending_enemy_transition
    return unless @pending_enemy_transition
    return if Kernel.tick_count < @pending_enemy_transition[:arrive_at]

    target_room = @rooms[@pending_enemy_transition[:target_room_id]]
    @enemy.enter_room(
      @pending_enemy_transition[:target_room_id],
      target_room.spawn(@pending_enemy_transition[:target_spawn_id]),
      target_room.play_area
    )
    @pending_enemy_transition = nil
  end

  def move_enemy_through_exit exit
    @pending_enemy_transition = nil
    target_room = @rooms[exit.target_room_id]
    @enemy.enter_room(exit.target_room_id, target_room.spawn(exit.target_spawn_id), target_room.play_area)
  end

  def exits
    interactables.find_all { |interactable| interactable.is_a?(Exit) }
  end

  def enemy_patrol_points room
    return archive_enemy_patrol_points if room.id == :archive

    room_exits = exits
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

  def interaction_text_for interactable
    return nil unless interactable
    return interactable.sacrificed_interaction_text if interactable.word && @sacrificed_words.include?(interactable.word)
    return interactable.sacrificed_interaction_text if sacrificed_object?(interactable.id)
    return interactable.interaction_text unless interactable.word
    return interactable.interaction_text if @learned_object_ids.include?(interactable.id)

    unless @learned_words.include?(interactable.word)
      @learned_words << interactable.word 
      @player.light_size = interactable.id == :lamp ? 2048 : 512
    end
    @learned_object_ids << interactable.id
    @learned_word_sources[interactable.word] = interactable.id
    "#{interactable.interaction_text} You remember that this is a #{interactable.word}."
  end

  def open_altar altar
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

    @player.light_size = 1024 if word == "LAMP"

    @learned_words.delete(word)
    @sacrificed_words << word unless @sacrificed_words.include?(word)

    @learned_word_sources.delete(word)
    all_interactables.each do |interactable|
      next unless interactable.word == word

      @sacrificed_object_ids << interactable.id unless @sacrificed_object_ids.include?(interactable.id)
      interactable.sacrifice!
    end

    close_altar
    set_interaction_text("You sacrificed #{word}.")
  end

  def sacrificeable_words
    @learned_words
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
    exit = interactables.find { |interactable| interactable.is_a?(Exit) && rects_intersect?(@player.rect, interactable.rect) }
    exit&.interact(self)
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
    interactables.each { |interactable| interactable.render(args, args.outputs[:scene], @camera) }
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

  def render_ui args
    args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    render_learned_words(args)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    render_altar(args) if @altar_open
    args.outputs.labels << Render.label(36, 40, "WASD / arrows move. R resets. Esc returns to title.", :ash, size_enum: -1)
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
