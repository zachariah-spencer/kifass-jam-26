class Game
  VIEWPORT_W = 1280
  VIEWPORT_H = 720
  WORLD_W = 2200
  WORLD_H = 1400
  PLAY_AREA = { x: 52, y: 58, w: WORLD_W - 104, h: WORLD_H - 116 }
  MESSAGE_DELAY_FRAMES = 3.seconds
  MESSAGE_CHARACTER_INTERVAL = 0.1.seconds

  attr_reader :player, :interactables, :camera

  def initialize
    restart
  end

  def restart
    @camera = Camera.new(VIEWPORT_W, VIEWPORT_H, WORLD_W, WORLD_H)
    @player = Player.new(WORLD_W / 2 - Player::SIZE / 2, WORLD_H / 2 - Player::SIZE / 2)
    @interactables = [
      Lamp.new(164, 552),
      Lamp.new(WORLD_W - 192, 552),
      Lamp.new(164, 132),
      Lamp.new(WORLD_W - 192, WORLD_H - 188),
      Lamp.new(WORLD_W / 2 - Lamp::SIZE / 2, WORLD_H / 2 + 180)
    ]
    @camera.snap_to(@player)
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
  end

  def update args
    handle_interaction(args)
    update_interaction_text
    @interactables.each { |interactable| interactable.update(args) }
    @player.update(args, PLAY_AREA)
    @camera.follow(@player)
  end

  def handle_interaction args
    return unless args.inputs.mouse.click

    click = @camera.world_point(args.inputs.mouse.click)
    interactable = @interactables.find { |candidate| candidate.contains_point?(click) }
    set_interaction_text(interactable&.interaction_text)
  end

  def set_interaction_text text
    @interaction_text = text
    @interaction_started_at = text ? Kernel.tick_count : nil
    @interaction_finished_at = nil
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
  end

  def visible_interaction_text
    return "" unless @interaction_text && @interaction_started_at

    elapsed = Kernel.tick_count - @interaction_started_at
    character_count = elapsed.idiv(MESSAGE_CHARACTER_INTERVAL) + 1
    @interaction_text[0, character_count.clamp(0, @interaction_text.length)]
  end

  def render args
    render_lit_scene(args)
    render_ui(args)
  end

  def render_lit_scene args
    args.outputs[:scene].set(w: Grid.w, h: Grid.h, background_color: [10, 9, 14, 255])
    args.outputs[:darkness].set(w: Grid.w, h: Grid.h, background_color: [0, 0, 0, 0])

    render_floor(args, args.outputs[:scene])
    @interactables.each { |interactable| interactable.render(args, args.outputs[:scene], @camera) }
    @player.render(args, args.outputs[:scene], @camera)
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    @interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    @player.render_light(args, args.outputs[:darkness], @camera)

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :scene }
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :darkness }
  end

  def render_floor args, outputs = args.outputs
    play_area = @camera.screen_rect(PLAY_AREA)
    outputs.sprites << Render.solid(play_area, :stone, a: 85)
    outputs.borders << play_area.merge(**Render.color(:wall))
  end

  def render_ui args
    args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    args.outputs.labels << Render.label(36, 40, "WASD / arrows move. R resets. Esc returns to title.", :ash, size_enum: -1)
  end
end
