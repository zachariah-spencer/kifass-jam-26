class Game
  attr_reader :player

  def initialize
    restart
  end

  def restart
    @player = Player.new(Grid.w / 2 - Player::SIZE / 2, Grid.h / 2 - Player::SIZE / 2)
  end

  def update args
    @player.update(args)
  end

  def render args
    render_lit_scene(args)
    render_ui(args)
  end

  def render_lit_scene args
    args.outputs[:scene].set(w: Grid.w, h: Grid.h, background_color: [10, 9, 14, 255])
    args.outputs[:darkness].set(w: Grid.w, h: Grid.h, background_color: [0, 0, 0, 0])

    render_floor(args, args.outputs[:scene])
    @player.render(args, args.outputs[:scene])
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    @player.render_light(args, args.outputs[:darkness])

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :scene }
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :darkness }
  end

  def render_floor args, outputs = args.outputs
    play_area = { x: 52, y: 58, w: Grid.w - 104, h: Grid.h - 116 }
    outputs.sprites << Render.solid(play_area, :stone, a: 85)
    outputs.borders << play_area.merge(**Render.color(:wall))
  end

  def render_ui args
    args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    args.outputs.labels << Render.label(36, 40, "WASD / arrows move. R resets. Esc returns to title.", :ash, size_enum: -1)
  end
end
