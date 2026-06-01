class Game
  def render_ending args
    return unless ending_sequence_triggered?

    alpha = ending_black_alpha
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: alpha } if alpha > 0
  end

  def ending_black_alpha
    case @ending_phase
    when :fade_black
      (ending_phase_elapsed * 255 / ENDING_FADE_BLACK_FRAMES).clamp(0, 255)
    when :final_text_fade_in, :title_fade_in
      (255 - ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text_fade_out, :title_fade_out
      (ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :done
      255
    else
      0
    end
  end

  def render_ending_ui args
    alpha = ending_card_text_alpha
    case @ending_phase
    when :final_text_fade_in, :final_text, :final_text_fade_out
      lines = visible_final_text_lines
      args.outputs.labels << Render.label(640, 430, lines[0], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
      args.outputs.labels << Render.label(640, 360, lines[1], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
      args.outputs.labels << Render.label(640, 290, lines[2], :ash, size_enum: 2, alignment_enum: 1, a: alpha)
    when :title_fade_in, :title_card, :title_fade_out
      text = ending_title_text
      args.outputs.labels << Render.label(640, 374, text, :ash, size_enum: 8, alignment_enum: 1, a: alpha)
    end
  end

  def ending_card_text_alpha
    case @ending_phase
    when :final_text_fade_in, :title_fade_in
      (ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text_fade_out, :title_fade_out
      (255 - ending_phase_elapsed * 255 / ENDING_CARD_FADE_FRAMES).clamp(0, 255)
    when :final_text, :title_card
      255
    else
      0
    end
  end

  def visible_final_text_lines
    lines = [
      "The door opens.",
      "Something leaves.",
      "It may have been you."
    ]
    return lines if @ending_phase == :final_text_fade_out

    visible_lines_for_character_count(lines, final_text_character_count)
  end

  def final_text_character_count
    elapsed = @ending_phase == :final_text ? ENDING_CARD_FADE_FRAMES + ending_phase_elapsed : ending_phase_elapsed
    elapsed.idiv(ENDING_MESSAGE_CHARACTER_INTERVAL) + 1
  end

  def final_text_lines_length
    "The door opens.".length +
      "Something leaves.".length +
      "It may have been you.".length
  end

  def final_text_ready_to_fade_out?
    final_text_total_elapsed >= final_text_complete_at + ENDING_TEXT_COMPLETE_DELAY_FRAMES
  end

  def final_text_total_elapsed
    ENDING_CARD_FADE_FRAMES + ending_phase_elapsed
  end

  def final_text_complete_at
    (final_text_lines_length - 1) * ENDING_MESSAGE_CHARACTER_INTERVAL
  end

  def visible_lines_for_character_count lines, character_count
    remaining = character_count
    lines.map do |line|
      visible_count = remaining.clamp(0, line.length)
      remaining -= line.length
      line[0, visible_count]
    end
  end

  def ending_title_text
    return "EPITHET" unless @ending_title_corruptor
    title_elapsed = Kernel.tick_count - @ending_title_started_at
    return "EPITHET" if title_elapsed < ENDING_TITLE_CORRUPT_AFTER_FRAMES

    elapsed = title_elapsed - ENDING_TITLE_CORRUPT_AFTER_FRAMES
    @ending_title_corruptor.text(elapsed)
  end
end
