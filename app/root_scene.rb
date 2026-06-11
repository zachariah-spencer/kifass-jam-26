class RootScene
  SCENE_FADE_OUT_FRAMES = 8
  SCENE_FADE_IN_FRAMES = 8
  MUSIC_GAIN = 0.5
  MUSIC_CROSSFADE_FRAMES = 1.5.seconds
  MUSIC_KEYS = [:bg_music_a, :bg_music_b]
  CHASE_MUSIC_KEY = :bg_brokenbells
  CHASE_MUSIC_PATH = "sounds/bg_brokenbells.ogg"
  CHASE_MUSIC_GAIN = 1.0
  CHASE_MUSIC_FADE_FRAMES = 0.25.seconds
  MENU_MUSIC_PATH = "sounds/bg_menu.ogg"
  ATMOSPHERE_MUSIC_PATH = "sounds/bg_atmosphere.ogg"
  SCENE_MUSIC = {
    title: MENU_MUSIC_PATH,
    name_entry: ATMOSPHERE_MUSIC_PATH,
    play: ATMOSPHERE_MUSIC_PATH
  }

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
    args.state.master_volume = 1.0 if args.state.master_volume.nil?
  end

  def tick
    defaults
    update_scene_transition
    update_music

    scene_before_tick = args.state.scene
    scene = current_scene
    scene.args = args
    scene.tick

    if args.state.scene != scene_before_tick
      raise "Do not change scene mid-tick. Set args.state.next_scene instead."
    end

    start_scene_transition if args.state.next_scene && !args.state.scene_transition
    update_music
    apply_master_volume
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

  def update_music
    if @game.final_sacrifice_music_stopped?
      if returning_to_title_after_ending?
        stop_chase_music
        update_ending_return_music
        return
      end

      stop_music
      stop_chase_music
      return
    end

    desired_input = SCENE_MUSIC[args.state.scene]
    return unless desired_input

    args.state.active_music_key ||= MUSIC_KEYS.first
    args.state.current_music_input ||= nil
    start_music(desired_input) unless active_music
    crossfade_music(desired_input) if args.state.current_music_input != desired_input
    update_music_crossfade
    update_chase_music
  end

  def returning_to_title_after_ending?
    return false unless @game.ending_complete?

    args.state.scene == :title ||
      args.state.next_scene == :title ||
      args.state.scene_transition&.[](:target_scene) == :title
  end

  def update_ending_return_music
    start_returning_menu_music unless active_music&.input == MENU_MUSIC_PATH
    update_music_crossfade
    update_ending_escaped_music_fade_out
  end

  def start_returning_menu_music
    args.state.active_music_key ||= MUSIC_KEYS.first
    args.audio[args.state.active_music_key] = {
      input: MENU_MUSIC_PATH,
      looping: true,
      base_gain: 0.0,
      gain: 0.0
    }
    args.state.current_music_input = MENU_MUSIC_PATH
    args.state.previous_music_key = nil
    args.state.music_crossfade_started_at = Kernel.tick_count
  end

  def update_ending_escaped_music_fade_out
    music = args.audio[Game::ENDING_ESCAPED_MUSIC_KEY]
    return unless music

    args.state.ending_escaped_music_fade_out_started_at ||= Kernel.tick_count
    args.state.ending_escaped_music_fade_out_from_gain ||= audio_base_gain(music)
    progress = ((Kernel.tick_count - args.state.ending_escaped_music_fade_out_started_at).to_f / MUSIC_CROSSFADE_FRAMES).clamp(0.0, 1.0)

    from_gain = args.state.ending_escaped_music_fade_out_from_gain || 0.0
    set_audio_base_gain(music, (from_gain * (1.0 - progress)).clamp(0.0, from_gain))
    return if progress < 1.0

    args.audio.delete(Game::ENDING_ESCAPED_MUSIC_KEY)
    args.state.ending_escaped_music_fade_out_started_at = nil
    args.state.ending_escaped_music_fade_out_from_gain = nil
  end

  def start_music input
    args.audio[args.state.active_music_key] = {
      input: input,
      looping: true,
      base_gain: MUSIC_GAIN,
      gain: MUSIC_GAIN * master_volume
    }
    args.state.current_music_input = input
  end

  def crossfade_music input
    old_key = args.state.active_music_key
    new_key = inactive_music_key

    args.audio.delete(new_key)
    args.audio[new_key] = {
      input: input,
      looping: true,
      base_gain: 0.0,
      gain: 0.0
    }
    args.state.previous_music_key = old_key
    args.state.active_music_key = new_key
    args.state.current_music_input = input
    args.state.music_crossfade_started_at = Kernel.tick_count
  end

  def update_music_crossfade
    fade_started_at = args.state.music_crossfade_started_at
    return unless fade_started_at

    progress = ((Kernel.tick_count - fade_started_at).to_f / MUSIC_CROSSFADE_FRAMES).clamp(0.0, 1.0)
    active = active_music
    previous = args.audio[args.state.previous_music_key]

    set_audio_base_gain(active, (MUSIC_GAIN * progress).clamp(0.0, MUSIC_GAIN)) if active
    set_audio_base_gain(previous, (MUSIC_GAIN * (1.0 - progress)).clamp(0.0, MUSIC_GAIN)) if previous

    return if progress < 1.0

    args.audio.delete(args.state.previous_music_key)
    args.state.previous_music_key = nil
    args.state.music_crossfade_started_at = nil
  end

  def active_music
    args.audio[args.state.active_music_key]
  end

  def stop_music
    MUSIC_KEYS.each { |key| args.audio.delete(key) }
    args.state.current_music_input = nil
    args.state.previous_music_key = nil
    args.state.music_crossfade_started_at = nil
  end

  def update_chase_music
    if @game.player_chased?
      start_chase_music unless chase_music
      set_chase_music_fade_direction(:in)
    elsif chase_music
      set_chase_music_fade_direction(:out)
    else
      clear_chase_music_state
      return
    end

    update_chase_music_fade
  end

  def start_chase_music
    args.audio[CHASE_MUSIC_KEY] = {
      input: CHASE_MUSIC_PATH,
      looping: true,
      base_gain: 0.0,
      gain: 0.0
    }
    args.state.chase_music_fade_started_at = Kernel.tick_count
    args.state.chase_music_fade_direction = :in
    args.state.chase_music_fade_from_gain = 0.0
  end

  def set_chase_music_fade_direction direction
    return if args.state.chase_music_fade_direction == direction

    args.state.chase_music_fade_from_gain = audio_base_gain(chase_music)
    args.state.chase_music_fade_started_at = Kernel.tick_count
    args.state.chase_music_fade_direction = direction
  end

  def update_chase_music_fade
    music = chase_music
    return unless music

    fade_started_at = args.state.chase_music_fade_started_at || Kernel.tick_count
    progress = ((Kernel.tick_count - fade_started_at).to_f / CHASE_MUSIC_FADE_FRAMES).clamp(0.0, 1.0)

    from_gain = args.state.chase_music_fade_from_gain || audio_base_gain(music)
    to_gain = args.state.chase_music_fade_direction == :out ? 0.0 : CHASE_MUSIC_GAIN
    set_audio_base_gain(music, (from_gain + (to_gain - from_gain) * progress).clamp(0.0, CHASE_MUSIC_GAIN))
    return if progress < 1.0

    if args.state.chase_music_fade_direction == :out
      stop_chase_music
    else
      args.state.chase_music_fade_from_gain = audio_base_gain(music)
    end
  end

  def chase_music
    args.audio[CHASE_MUSIC_KEY]
  end

  def stop_chase_music
    args.audio.delete(CHASE_MUSIC_KEY)
    clear_chase_music_state
  end

  def clear_chase_music_state
    args.state.chase_music_fade_started_at = nil
    args.state.chase_music_fade_direction = nil
    args.state.chase_music_fade_from_gain = nil
  end

  def inactive_music_key
    (MUSIC_KEYS - [args.state.active_music_key]).first
  end

  def master_volume
    (args.state.master_volume || 1.0).clamp(0.0, 1.0)
  end

  def apply_master_volume
    args.audio.each_value do |audio|
      set_audio_base_gain(audio, audio_base_gain(audio))
    end
  end

  def audio_base_gain audio
    return 0.0 unless audio

    audio.base_gain = audio.gain || 0.0 if audio.base_gain.nil?
    audio.base_gain || 0.0
  end

  def set_audio_base_gain audio, gain
    return unless audio

    audio.base_gain = gain
    audio.gain = gain * master_volume
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
