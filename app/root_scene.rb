class RootScene
  SCENE_FADE_OUT_FRAMES = 8
  SCENE_FADE_IN_FRAMES = 8

  attr_accessor :args
  attr_reader :game

  def initialize
    @game = Game.new
    @scenes = [
      TitleScene.new(@game),
      NameEntryScene.new(@game),
      PlayScene.new(@game)
    ]
  end

  def defaults
    args.state.scene ||= :title
    args.state.scene_changed_at ||= Kernel.tick_count
  end

  def tick
    defaults
    update_scene_transition

    scene_before_tick = args.state.scene
    scene = current_scene
    scene.args = args
    scene.tick

    if args.state.scene != scene_before_tick
      raise "Do not change scene mid-tick. Set args.state.next_scene instead."
    end

    start_scene_transition if args.state.next_scene && !args.state.scene_transition
    render_transition
  end

  def current_scene
    scene = @scenes.find { |candidate| candidate.id == args.state.scene }
    raise "Scene with id #{args.state.scene} does not exist." unless scene

    scene
  end

  def start_scene_transition
    args.state.scene_transition = {
      target_scene: args.state.next_scene,
      phase: :fade_out,
      started_at: Kernel.tick_count
    }
  end

  def update_scene_transition
    transition = args.state.scene_transition
    return unless transition

    elapsed = Kernel.tick_count - transition[:started_at]
    if transition[:phase] == :fade_out && elapsed >= SCENE_FADE_OUT_FRAMES
      commit_scene_change
      transition[:phase] = :fade_in
      transition[:started_at] = Kernel.tick_count
    elsif transition[:phase] == :fade_in && elapsed >= SCENE_FADE_IN_FRAMES
      args.state.scene_transition = nil
    end
  end

  def commit_scene_change
    transition = args.state.scene_transition
    previous = current_scene
    previous.deactivate!

    args.state.previous_scene = args.state.scene
    args.state.scene = transition[:target_scene]
    args.state.next_scene = nil
    args.state.scene_changed_at = Kernel.tick_count

    current_scene.args = args
    current_scene.activate!
  end

  def render_transition
    transition = args.state.scene_transition
    return unless transition

    elapsed = Kernel.tick_count - transition[:started_at]
    alpha = if transition[:phase] == :fade_out
              elapsed * 255 / SCENE_FADE_OUT_FRAMES
            else
              255 - elapsed * 255 / SCENE_FADE_IN_FRAMES
            end

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha.clamp(0, 255) }
  end
end
