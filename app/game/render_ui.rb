class Game
  def render_ui args
    return render_ending_ui(args) if ending_sequence_triggered? && @ending_phase != :sacrifice_message

    # args.outputs.labels << Render.label(36, 694, "PLAY SCENE", :ash, size_enum: 3)
    render_learned_words(args)
    if @interaction_text
      args.outputs.labels << Render.label(640, 664, visible_interaction_text, :ash, size_enum: 1, alignment_enum: 1)
    end
    render_mechanic_feedback(args)
    render_bell_cooldown_indicator(args)
    render_archive_off_path_warning(args)
    render_altar(args) if @altar_open
    args.outputs.labels << Render.label(36, 40, "Press R to forget it all...", :ash, size_enum: -1)
  end

  def render_archive_off_path_warning args
    return unless archive_off_path_warning_active?

    args.outputs.labels << Render.label(640, 142, ARCHIVE_OFF_PATH_WARNING_TEXT, :ember, size_enum: 1, alignment_enum: 1, a: 230)
  end

  def render_bell_cooldown_indicator args
    progress = bell_cooldown_progress
    pulse_active = @bell_failed_pulse_until && Kernel.tick_count < @bell_failed_pulse_until
    return if progress <= 0 && !pulse_active

    center = @camera.screen_point(@player.center)
    cx = center[:x]
    cy = center[:y] + 62
    pulse_scale = bell_failed_pulse_scale
    radius = 20.lerp(24, pulse_scale)
    segments = 18
    active_segments = (segments * progress).ceil
    color = Render.color(:ash)
    alpha = 190.lerp(245, pulse_scale).to_i

    segments.times do |index|
      next if progress > 0 && index >= active_segments

      angle_a = Math::PI * 2 * index / segments + Math::PI / 2
      angle_b = Math::PI * 2 * (index + 0.72) / segments + Math::PI / 2
      args.outputs.lines << {
        x: cx + Math.cos(angle_a) * radius,
        y: cy + Math.sin(angle_a) * radius,
        x2: cx + Math.cos(angle_b) * radius,
        y2: cy + Math.sin(angle_b) * radius,
        r: color[:r],
        g: color[:g],
        b: color[:b],
        a: alpha
      }
    end
  end

  def bell_failed_pulse_scale
    return 0 unless @bell_failed_pulse_until

    remaining = @bell_failed_pulse_until - Kernel.tick_count
    return 0 if remaining <= 0

    elapsed = BELL_FAILED_PULSE_FRAMES - remaining
    progress = (elapsed.to_f / BELL_FAILED_PULSE_FRAMES).clamp(0, 1)
    midpoint = 0.5

    if progress < midpoint
      0.lerp(1, progress / midpoint)
    else
      1.lerp(0, (progress - midpoint) / midpoint)
    end
  end

  def render_mechanic_feedback args
    return unless @mechanic_feedback_text && @mechanic_feedback_started_at && @mechanic_feedback_until
    return if Kernel.tick_count >= @mechanic_feedback_until

    lines = @mechanic_feedback_text.wrapped_lines(76)
    return if lines.empty?

    outputs = args.outputs.primitives
    alpha_scale = mechanic_feedback_alpha_scale
    panel = { x: 286, y: (Grid.h - (24 + lines.length * 24)) / 2, w: 708, h: 24 + lines.length * 24 }
    outputs << panel.merge(**Render.color(:stone), a: (128 * alpha_scale).to_i, primitive_marker: :solid)
    outputs << panel.merge(**Render.color(:ember), a: (220 * alpha_scale).to_i, primitive_marker: :border)
    lines.each_with_index do |line, index|
      outputs << Render.label(640, panel[:y] + panel[:h] - 17 - index * 24, line, :ember, size_enum: 0, alignment_enum: 1, a: (255 * alpha_scale).to_i).merge(primitive_marker: :label)
    end
  end

  def mechanic_feedback_alpha_scale
    elapsed = Kernel.tick_count - @mechanic_feedback_started_at
    remaining = @mechanic_feedback_until - Kernel.tick_count
    fade_frames = [MECHANIC_FEEDBACK_FADE_FRAMES, MECHANIC_FEEDBACK_FRAMES / 2].min

    if elapsed < fade_frames
      elapsed.to_f / fade_frames
    elsif remaining < fade_frames
      remaining.to_f / fade_frames
    else
      1
    end.clamp(0, 1)
  end

  def render_learned_words args
    outputs = args.outputs.primitives
    outputs << Render.label(1080, 694, "LEARNED", :ash, size_enum: 1)

    learned_rows = @learned_words.empty? ? 1 : @learned_words.length
    if @learned_words.empty?
      outputs << Render.label(1080, 664, "none", :ash, size_enum: -1)
    else
      @learned_words.each_with_index do |word, index|
        outputs << Render.label(1080, 664 - index * 24, word, :ember, size_enum: 0)
      end
    end

    render_forgotten_words(outputs, 664 - learned_rows * 24 - 12)
  end

  def render_forgotten_words outputs, y
    return if @sacrificed_words.empty?

    outputs << Render.label(1080, y, "FORGOTTEN", :ash, size_enum: 0, a: 135)
    @sacrificed_words.each_with_index do |word, index|
      outputs << Render.label(1080, y - 24 - index * 20, forgotten_word_text(word), :brass, size_enum: -1, a: 125)
    end
  end

  def forgotten_word_text word
    @forgotten_word_corruptors ||= {}
    @forgotten_word_corruptors[word] ||= TextCorruptor.new(word)
    @forgotten_word_corruptors[word].text(Kernel.tick_count)
  end

  def render_altar args
    outputs = args.outputs.primitives
    outputs << { x: 0, y: 0, w: Grid.w, h: Grid.h, **Render.color(:void), a: 150, primitive_marker: :solid }
    outputs << ALTAR_PANEL.merge(**Render.color(:stone), a: 128, primitive_marker: :solid)
    outputs << ALTAR_PANEL.merge(**Render.color(:brass), primitive_marker: :border)
    outputs << Render.label(640, 478, "SACRIFICE A NAME", :ash, size_enum: 2, alignment_enum: 1).merge(primitive_marker: :label)

    if sacrificeable_words.empty?
      outputs << Render.label(640, 388, "No learned names.", :ash, size_enum: 0, alignment_enum: 1).merge(primitive_marker: :label)
      outputs << Render.label(640, 246, "Click away to close.", :ash, size_enum: -1, alignment_enum: 1).merge(primitive_marker: :label)
      return
    end

    sacrificeable_words.each_with_index do |word, index|
      rect = altar_word_rect(index)
      outputs << rect.merge(**Render.color(:wall), primitive_marker: :solid)
      outputs << rect.merge(**Render.color(:ember), primitive_marker: :border)
      outputs << Render.label(rect[:x] + 18, rect[:y] + 24, word, :ember, size_enum: 0).merge(primitive_marker: :label)
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
