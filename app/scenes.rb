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
    return false if args.state.scene_transition
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
      args.state.next_scene = :name_entry
    end
  end

  def render
    alpha = title_fade_alpha
    args.outputs.sprites << Render.fullscreen(:void)
    args.outputs.labels << Render.label(640, 438, "EPITHET", :ash, size_enum: 8, alignment_enum: 1, a: alpha)
    args.outputs.labels << Render.label(640, 284, "E / Enter / Click to begin", :ember, size_enum: 2, alignment_enum: 1, a: alpha)
    args.outputs.labels << Render.label(640, 52, "WASD or arrows move. R resets. Esc returns here.", :ash, size_enum: -1, alignment_enum: 1, a: alpha)
  end

  def title_fade_alpha
    return 255 unless args.state.scene_changed_at

    elapsed = Kernel.tick_count - args.state.scene_changed_at
    (elapsed * 255 / Render::TRANSITION_FRAMES).clamp(0, 255)
  end
end

class NameEntryScene < BaseScene
  PROMPT_TEXT = "What is your name?"
  MAX_NAME_LENGTH = 16
  PROMPT_DELAY_FRAMES = 1.seconds
  PROMPT_FADE_FRAMES = 0.5.seconds
  KEYBOARD_FADE_FRAMES = 0.7.seconds
  UI_FADE_OUT_FRAMES = 0.55.seconds
  THANKS_FADE_FRAMES = 0.9.seconds
  THANKS_COMPLETE_DELAY_FRAMES = 2.seconds
  KEY_W = 58
  KEY_H = 42
  KEY_GAP = 10
  KEYBOARD_ROWS = [
    "QWERTYUIOP".chars,
    "ASDFGHJKL".chars,
    "ZXCVBNM".chars
  ]
  SPECIAL_KEYS = [
    { text: "SPACE", value: :space, w: KEY_W * 3 + KEY_GAP * 2 },
    { text: "DELETE", value: :backspace, w: KEY_W * 2 + KEY_GAP },
    { text: "ENTER", value: :submit, w: KEY_W * 2 + KEY_GAP }
  ]

  def id
    :name_entry
  end

  def activate!
    @phase = :prompt_delay
    @phase_started_at = Kernel.tick_count
    @name = ""
    @submitted_name = nil
  end

  def tick
    update
    render
  end

  def update
    case @phase
    when :prompt_delay
      set_phase(:prompt) if phase_elapsed >= PROMPT_DELAY_FRAMES
    when :prompt
      set_phase(:input) if prompt_complete?
    when :input
      handle_name_input if accepts_input?
    when :ui_fade_out
      set_phase(:thanks_fade_in) if phase_elapsed >= UI_FADE_OUT_FRAMES
    when :thanks_fade_in
      set_phase(:thanks_hold) if phase_elapsed >= THANKS_FADE_FRAMES
    when :thanks_hold
      set_phase(:thanks_fade_out) if thanks_ready_to_fade_out?
    when :thanks_fade_out
      args.state.next_scene = :play if phase_elapsed >= THANKS_FADE_FRAMES
    end
  end

  def handle_name_input
    typed = args.inputs.keyboard.key_down.char
    add_character(typed) if printable_character?(typed)

    remove_character if args.inputs.keyboard.key_down.backspace
    submit_name if args.inputs.keyboard.key_down.enter

    click = args.inputs.mouse.click
    return unless click

    key = key_at(click)
    return unless key

    case key[:value]
    when :space
      add_character(" ")
    when :backspace
      remove_character
    when :submit
      submit_name
    else
      add_character(key[:value])
    end
  end

  def add_character character
    return if @name.length >= MAX_NAME_LENGTH
    return if character == " " && @name.empty?

    @name << character.upcase
  end

  def printable_character? character
    return false unless character && character.length == 1

    codepoint = character.ord
    codepoint >= 32 && codepoint <= 126
  end

  def remove_character
    @name = @name[0...-1] || ""
  end

  def submit_name
    stripped_name = @name.strip
    return if stripped_name.empty?

    @submitted_name = stripped_name
    @game.player_name = stripped_name
    set_phase(:ui_fade_out)
  end

  def set_phase phase
    @phase = phase
    @phase_started_at = Kernel.tick_count
  end

  def phase_elapsed
    Kernel.tick_count - @phase_started_at
  end

  def prompt_complete?
    return false if @phase == :prompt_delay

    visible_prompt_text.length == PROMPT_TEXT.length
  end

  def visible_prompt_text
    return "" if @phase == :prompt_delay
    return PROMPT_TEXT unless @phase == :prompt

    character_count = phase_elapsed.idiv(Game::MESSAGE_CHARACTER_INTERVAL) + 1
    PROMPT_TEXT[0, character_count.clamp(0, PROMPT_TEXT.length)]
  end

  def render
    args.outputs.sprites << Render.fullscreen(:void)
    render_prompt_and_keyboard
    render_thanks
  end

  def render_prompt_and_keyboard
    alpha = prompt_alpha
    return if alpha <= 0

    args.outputs.labels << Render.label(640, 512, visible_prompt_text, :ash, size_enum: 3, alignment_enum: 1, a: alpha)
    render_name_field(alpha)
    render_keyboard(keyboard_alpha(alpha))
  end

  def render_name_field alpha
    return unless [:input, :ui_fade_out].include?(@phase)

    field = { x: 420, y: 394, w: 440, h: 58 }
    args.outputs.sprites << Render.solid(field, :wall, a: (170 * alpha / 255).clamp(0, 255))
    args.outputs.borders << field.merge(**Render.color(:brass), a: alpha)
    args.outputs.labels << Render.label(640, 433, @name, :ember, size_enum: 2, alignment_enum: 1, a: alpha)
  end

  def render_keyboard alpha
    return if alpha <= 0

    keyboard_keys.each do |key|
      active = key[:value] != :submit || name_ready?
      key_alpha = active ? alpha : (alpha * 88 / 255)
      args.outputs.sprites << Render.solid(key_rect(key), :wall, a: (180 * key_alpha / 255).clamp(0, 255))
      args.outputs.borders << key_rect(key).merge(**Render.color(active ? :ember : :stone), a: key_alpha)
      args.outputs.labels << Render.label(key[:x] + key[:w] / 2, key[:y] + 27, key[:text], active ? :ash : :stone, size_enum: -1, alignment_enum: 1, a: key_alpha)
    end
  end

  def render_thanks
    alpha = thanks_alpha
    return if alpha <= 0

    lines = visible_thanks_lines
    args.outputs.labels << Render.label(640, 408, lines[0], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
    args.outputs.labels << Render.label(640, 348, lines[1], :ash, size_enum: 1, alignment_enum: 1, a: alpha)
  end

  def prompt_alpha
    return 0 if @phase == :prompt_delay
    return (phase_elapsed * 255 / PROMPT_FADE_FRAMES).clamp(0, 255) if @phase == :prompt
    return 255 if @phase == :input
    return 0 unless @phase == :ui_fade_out

    (255 - phase_elapsed * 255 / UI_FADE_OUT_FRAMES).clamp(0, 255)
  end

  def keyboard_alpha base_alpha
    return 0 if @phase == :prompt
    return base_alpha if @phase != :input

    (phase_elapsed * 255 / KEYBOARD_FADE_FRAMES).clamp(0, base_alpha)
  end

  def thanks_alpha
    case @phase
    when :thanks_fade_in
      (phase_elapsed * 255 / THANKS_FADE_FRAMES).clamp(0, 255)
    when :thanks_hold
      255
    when :thanks_fade_out
      (255 - phase_elapsed * 255 / THANKS_FADE_FRAMES).clamp(0, 255)
    else
      0
    end
  end

  def visible_thanks_lines
    lines = [
      "Thank you, #{@submitted_name}...",
      "Our identities and our memories of them are what make us, after all..."
    ]
    return lines if @phase == :thanks_fade_out

    visible_lines_for_character_count(lines, thanks_character_count)
  end

  def thanks_character_count
    elapsed = @phase == :thanks_hold ? THANKS_FADE_FRAMES + phase_elapsed : phase_elapsed
    elapsed.idiv(Game::MESSAGE_CHARACTER_INTERVAL) + 1
  end

  def visible_thanks_text_length
    "Thank you, #{@submitted_name}...".length +
      "Our identities and our memories of them are what make us, after all...".length
  end

  def thanks_ready_to_fade_out?
    thanks_total_elapsed >= thanks_complete_at + THANKS_COMPLETE_DELAY_FRAMES
  end

  def thanks_total_elapsed
    THANKS_FADE_FRAMES + phase_elapsed
  end

  def thanks_complete_at
    (visible_thanks_text_length - 1) * Game::MESSAGE_CHARACTER_INTERVAL
  end

  def visible_lines_for_character_count lines, character_count
    remaining = character_count
    lines.map do |line|
      visible_count = remaining.clamp(0, line.length)
      remaining -= line.length
      line[0, visible_count]
    end
  end

  def name_ready?
    !@name.strip.empty?
  end

  def key_at point
    keyboard_keys.find { |key| point_inside_rect?(point, key_rect(key)) }
  end

  def keyboard_keys
    keys = []
    KEYBOARD_ROWS.each_with_index do |row, row_index|
      row_w = row.length * KEY_W + (row.length - 1) * KEY_GAP
      start_x = (Grid.w - row_w) / 2
      y = 298 - row_index * 58
      row.each_with_index do |letter, index|
        keys << { text: letter, value: letter, x: start_x + index * (KEY_W + KEY_GAP), y: y, w: KEY_W, h: KEY_H }
      end
    end

    keys + special_keys
  end

  def special_keys
    row_w = SPECIAL_KEYS.map { |key| key[:w] }.sum + (SPECIAL_KEYS.length - 1) * KEY_GAP
    x = (Grid.w - row_w) / 2
    y = 124

    SPECIAL_KEYS.map do |key|
      positioned_key = key.merge(x: x, y: y, h: KEY_H)
      x += key[:w] + KEY_GAP
      positioned_key
    end
  end

  def key_rect key
    { x: key[:x], y: key[:y], w: key[:w], h: key[:h] }
  end

  def point_inside_rect? point, rect
    point_x = point.is_a?(Hash) ? point[:x] : point.x
    point_y = point.is_a?(Hash) ? point[:y] : point.y
    point_x >= rect[:x] && point_x <= rect[:x] + rect[:w] && point_y >= rect[:y] && point_y <= rect[:y] + rect[:h]
  end
end

class PlayScene < BaseScene
  def id
    :play
  end

  def tick
    if @game.ending_complete?
      args.state.next_scene = :title
      return @game.render(args)
    end

    if !@game.input_locked? && args.inputs.keyboard.key_down.r
      @game.request_give_up_reset
      return @game.render(args)
    end

    if !@game.input_locked? && args.inputs.keyboard.key_down.escape
      args.state.next_scene = :title
      return @game.render(args)
    end

    @game.update(args) if accepts_input?
    @game.render(args)
  end
end
