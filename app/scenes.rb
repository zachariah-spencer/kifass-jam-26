class BaseScene
  attr_accessor :args
  attr_reader :game

  def initialize game
    @game = game
  end

  def id
    raise "Set scene id on #{self.class}."
  end

  def activate!
  end

  def deactivate!
  end

  def tick
    render
  end

  def render
  end

  def accepts_input?
    return true unless args.state.scene_changed_at

    Kernel.tick_count - args.state.scene_changed_at > 12
  end
end

class TitleScene < BaseScene
  def id
    :title
  end

  def tick
    render
    return unless accepts_input?

    if args.inputs.keyboard.key_down.e || args.inputs.keyboard.key_down.enter || args.inputs.mouse.click
      @game.restart
      args.state.next_scene = :play
    end
  end

  def render
    args.outputs.sprites << Render.fullscreen(:void)
    args.outputs.labels << Render.label(640, 438, "EPITHET", :ash, size_enum: 8, alignment_enum: 1)
    args.outputs.labels << Render.label(640, 364, "", :ash, size_enum: 1, alignment_enum: 1)
    args.outputs.labels << Render.label(640, 284, "E / Enter / Click to begin", :ember, size_enum: 2, alignment_enum: 1)
    args.outputs.labels << Render.label(640, 52, "WASD or arrows move. R resets. Esc returns here.", :ash, size_enum: -1, alignment_enum: 1)
  end
end

class PlayScene < BaseScene
  def id
    :play
  end

  def tick
    if args.inputs.keyboard.key_down.r
      @game.restart
      return @game.render(args)
    end

    if args.inputs.keyboard.key_down.escape
      args.state.next_scene = :title
      return @game.render(args)
    end

    @game.update(args) if accepts_input?
    @game.render(args)
  end
end
