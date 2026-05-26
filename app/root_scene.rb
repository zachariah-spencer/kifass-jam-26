class RootScene
  attr_accessor :args
  attr_reader :game

  def initialize
    @game = Game.new
    @scenes = [
      TitleScene.new(@game),
      PlayScene.new(@game)
    ]
  end

  def defaults
    args.state.scene ||= :title
    args.state.scene_changed_at ||= Kernel.tick_count
  end

  def tick
    defaults
    scene_before_tick = args.state.scene
    scene = current_scene
    scene.args = args
    scene.tick

    if args.state.scene != scene_before_tick
      raise "Do not change scene mid-tick. Set args.state.next_scene instead."
    end

    commit_scene_change if args.state.next_scene
    render_transition
  end

  def current_scene
    scene = @scenes.find { |candidate| candidate.id == args.state.scene }
    raise "Scene with id #{args.state.scene} does not exist." unless scene

    scene
  end

  def commit_scene_change
    previous = current_scene
    previous.deactivate!

    args.state.previous_scene = args.state.scene
    args.state.scene = args.state.next_scene
    args.state.next_scene = nil
    args.state.scene_changed_at = Kernel.tick_count

    current_scene.args = args
    current_scene.activate!
  end

  def render_transition
    elapsed = Kernel.tick_count - args.state.scene_changed_at
    return if elapsed > Render::TRANSITION_FRAMES

    half = Render::TRANSITION_FRAMES / 2
    alpha = if elapsed <= half
              180 - (elapsed * 120 / half)
            else
              60 - ((elapsed - half) * 60 / half)
            end

    args.outputs.sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha.clamp(0, 180) }
  end
end
