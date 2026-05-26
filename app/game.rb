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
    args.outputs.sprites << Render.fullscreen(:void)
    render_floor(args)
    @player.render(args)
    render_ui(args)
  end

  def render_floor args
    play_area = { x: 52, y: 58, w: Grid.w - 104, h: Grid.h - 116 }
    args.outputs.sprites << Render.solid(play_area, :stone, a: 85)
    args.outputs.borders << play_area.merge(**Render.color(:wall))
  end

  def render_ui args
    args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    args.outputs.labels << Render.label(36, 40, "WASD / arrows move. R resets. Esc returns to title.", :ash, size_enum: -1)
  end
end
