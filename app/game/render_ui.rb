class Game
  def render_ui args
    return render_ending_ui(args) if ending_sequence_triggered? && @ending_phase != :sacrifice_message

    # args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    render_learned_words(args)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    render_mechanic_feedback(args)
    render_altar(args) if @altar_open
    args.outputs.labels << Render.label(36, 40, "Press R to forget it all...", :ash, size_enum: -1)
  end

  def render_mechanic_feedback args
    return unless @mechanic_feedback_text && @mechanic_feedback_until
    return if Kernel.tick_count >= @mechanic_feedback_until

    lines = @mechanic_feedback_text.wrapped_lines(76)
    return if lines.empty?

    panel = { x: 286, y: 86, w: 708, h: 24 + lines.length * 24 }
    args.outputs.sprites << Render.solid(panel, :void, a: 210)
    args.outputs.borders << panel.merge(**Render.color(:ember), a: 220)
    lines.each_with_index do |line, index|
      args.outputs.labels << Render.label(640, panel[:y] + panel[:h] - 17 - index * 24, line, :ember, size_enum: 0, alignment_enum: 1)
    end
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

  def render_reset_sequence args
    return unless reset_sequence_active?

    black_alpha = reset_black_alpha
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: black_alpha } if black_alpha > 0

    hint_alpha = reset_hint_alpha
    return if hint_alpha <= 0

    args.outputs.labels << Render.label(640, 360, @reset_sequence[:hint], :ash, size_enum: 3, alignment_enum: 1, a: hint_alpha)
  end

  def reset_black_alpha
    elapsed = reset_sequence_elapsed
    case @reset_sequence[:phase]
    when :fade_out
      (elapsed * 255 / reset_fade_out_frames).clamp(0, 255)
    when :fade_in
      (255 - elapsed * 255 / reset_fade_in_frames).clamp(0, 255)
    else
      255
    end
  end

  def reset_hint_alpha
    return 0 unless @reset_sequence[:show_hint]

    elapsed = reset_sequence_elapsed
    case @reset_sequence[:phase]
    when :hint_fade_in
      (elapsed * 255 / RESET_HINT_FADE_FRAMES).clamp(0, 255)
    when :hint_hold
      255
    when :hint_fade_out
      (255 - elapsed * 255 / RESET_HINT_FADE_FRAMES).clamp(0, 255)
    else
      0
    end
  end
end
