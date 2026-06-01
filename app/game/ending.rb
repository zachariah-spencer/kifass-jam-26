class Game
  def set_interaction_text text
    @interaction_text = text
    @interaction_started_at = text ? Kernel.tick_count : nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = sacrificed_word_from_text(text)
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
    @interaction_scramble_sound_played = false
    @interaction_visible_character_count = 0
  end

  def start_ending_sequence
    @ending_sequence_triggered = true
    @ending_phase = :sacrifice_message
    @ending_phase_started_at = Kernel.tick_count
    clear_pointer_gesture
    @player.stop!
    @ending_monsters_fade_started_at = Kernel.tick_count
    @enemies.each(&:start_final_fade!)
  end

  def update_ending_sequence args
    update_interaction_text(args, true)
    interactables.each { |interactable| interactable.update(args) }
    @player.stop! unless @ending_phase == :player_walks
    advance_ending_phase if ending_phase_complete?
    update_final_text_typing_sound(args)
    update_ending_player_walk if @ending_phase == :player_walks
    update_player_footsteps(args, @ending_phase == :player_walks)
    @camera.follow(@player) if @ending_phase == :player_walks
  end

  def advance_ending_phase
    case @ending_phase
    when :sacrifice_message
      clear_interaction_text
      set_ending_phase(:door_opens)
    when :door_opens
      prepare_ending_walk
      @player.force_run_animation!
      set_ending_phase(:player_walks)
    when :player_walks
      @player.force_idle_animation!
      set_ending_phase(:player_fades)
    when :player_fades
      set_ending_phase(:fade_black)
    when :fade_black
      set_ending_phase(:final_text_fade_in)
    when :final_text_fade_in
      set_ending_phase(:final_text)
    when :final_text
      set_ending_phase(:final_text_fade_out)
    when :final_text_fade_out
      @ending_title_corruptor = TextCorruptor.new("EPITHET")
      @ending_title_started_at = Kernel.tick_count
      set_ending_phase(:title_fade_in)
    when :title_fade_in
      set_ending_phase(:title_card)
    when :title_card
      set_ending_phase(:title_fade_out)
    when :title_fade_out
      set_ending_phase(:done)
    end
  end

  def set_ending_phase phase
    @ending_phase = phase
    @ending_phase_started_at = Kernel.tick_count
    @ending_final_text_visible_character_count = 0 if phase == :final_text_fade_in
  end

  def ending_phase_complete?
    case @ending_phase
    when :sacrifice_message
      final_sacrifice_message_complete?
    when :door_opens
      ending_phase_elapsed >= ENDING_DOOR_OPEN_FRAMES
    when :player_fades
      ending_phase_elapsed >= ENDING_PLAYER_FADE_FRAMES
    when :player_walks
      ending_phase_elapsed >= ENDING_PLAYER_WALK_FRAMES
    when :fade_black
      ending_phase_elapsed >= ENDING_FADE_BLACK_FRAMES
    when :final_text_fade_in, :final_text_fade_out, :title_fade_in, :title_fade_out
      ending_phase_elapsed >= ENDING_CARD_FADE_FRAMES
    when :final_text
      final_text_ready_to_fade_out?
    when :title_card
      ending_phase_elapsed >= ENDING_TITLE_FRAMES
    else
      false
    end
  end

  def ending_phase_elapsed
    Kernel.tick_count - @ending_phase_started_at
  end

  def final_sacrifice_message_complete?
    return false unless @interaction_text && @interaction_finished_at
    return false unless sacrifice_scramble_complete?

    Kernel.tick_count - @interaction_finished_at >= MESSAGE_DELAY_FRAMES
  end

  def sacrifice_scramble_complete?
    return true unless @interaction_sacrificed_word

    non_space_count = @interaction_sacrificed_word.length - @interaction_sacrificed_word.count(" ")
    Kernel.tick_count - @interaction_finished_at >= non_space_count * SACRIFICE_SCRAMBLE_INTERVAL
  end

  def prepare_ending_walk
    door = final_door
    return unless door

    @ending_player_start = { x: @player.x, y: @player.y }
    @ending_player_target = {
      x: door.center[:x] - @player.w / 2,
      y: door.center[:y] - @player.h / 2
    }
    @player.face_toward_x(@ending_player_target[:x])
  end

  def update_ending_player_walk
    return unless @ending_player_start && @ending_player_target

    progress = (ending_phase_elapsed.to_f / ENDING_PLAYER_WALK_FRAMES).clamp(0, 1)
    @player.x = @ending_player_start[:x].lerp(@ending_player_target[:x], progress)
    @player.y = @ending_player_start[:y].lerp(@ending_player_target[:y], progress)
  end

  def final_door
    interactables.find { |interactable| interactable.is_a?(FinalDoor) }
  end

  def update_interaction_text args, hold_final_sacrifice = false
    return unless @interaction_text

    visible_character_count = visible_interaction_text.length
    if visible_character_count > (@interaction_visible_character_count || 0) && visible_character_count.odd?
      play_typing_sound(args)
    end
    @interaction_visible_character_count = visible_character_count

    if visible_character_count == @interaction_text.length
      @interaction_finished_at ||= Kernel.tick_count
      update_sacrifice_scramble_sound(args)
      clear_interaction_text if !hold_final_sacrifice && Kernel.tick_count - @interaction_finished_at >= MESSAGE_DELAY_FRAMES
    end
  end

  def update_sacrifice_scramble_sound args
    return unless @interaction_sacrificed_word && @interaction_finished_at
    return if @interaction_scramble_sound_played
    return if @interaction_sacrificed_word.length == @interaction_sacrificed_word.count(" ")
    return if Kernel.tick_count - @interaction_finished_at < SACRIFICE_SCRAMBLE_INTERVAL

    @interaction_scramble_sound_played = true
    play_scramble_sound(args)
  end

  def update_final_text_typing_sound args
    return unless [:final_text_fade_in, :final_text].include?(@ending_phase)

    visible_character_count = final_text_character_count.clamp(0, final_text_lines_length)
    if visible_character_count > (@ending_final_text_visible_character_count || 0) && visible_character_count.odd?
      play_typing_sound(args)
    end
    @ending_final_text_visible_character_count = visible_character_count
  end

  def clear_interaction_text
    @interaction_text = nil
    @interaction_started_at = nil
    @interaction_finished_at = nil
    @interaction_sacrificed_word = nil
    @interaction_scrambled_word = nil
    @interaction_scrambled_at = nil
    @interaction_scramble_order = nil
    @interaction_scramble_sound_played = false
    @interaction_visible_character_count = 0
  end

  def visible_interaction_text
    return "" unless @interaction_text && @interaction_started_at

    elapsed = Kernel.tick_count - @interaction_started_at
    character_count = elapsed.idiv(MESSAGE_CHARACTER_INTERVAL) + 1
    current_interaction_text[0, character_count.clamp(0, @interaction_text.length)]
  end

  def current_interaction_text
    return @interaction_text unless @interaction_sacrificed_word && @interaction_finished_at

    @interaction_text.sub(@interaction_sacrificed_word, scrambled_sacrificed_word)
  end

  def scrambled_sacrificed_word
    elapsed = Kernel.tick_count - @interaction_finished_at
    @interaction_scramble_order ||= random_sacrifice_scramble_order(@interaction_sacrificed_word)
    scramble_count = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL).clamp(0, @interaction_scramble_order.length)
    scramble_tick = elapsed.idiv(SACRIFICE_SCRAMBLE_INTERVAL)
    return @interaction_scrambled_word if @interaction_scrambled_at == scramble_tick && @interaction_scrambled_word

    @interaction_scrambled_word ||= @interaction_sacrificed_word.dup
    scramble_count.times do |index|
      word_index = @interaction_scramble_order[index]
      @interaction_scrambled_word[word_index] = SACRIFICE_SCRAMBLE_SYMBOLS[rand(SACRIFICE_SCRAMBLE_SYMBOLS.length)]
    end
    @interaction_scrambled_at = scramble_tick

    @interaction_scrambled_word
  end

  def random_sacrifice_scramble_order word = @interaction_sacrificed_word
    order = []
    word.length.times do |index|
      next if word[index] == " "

      insert_at = order.length == 0 ? 0 : rand(order.length + 1)
      order.insert(insert_at, index)
    end

    order
  end

  def sacrificed_word_from_text text
    return nil unless text

    prefix = "You sacrificed "
    suffix = "."
    return nil unless text.start_with?(prefix) && text.end_with?(suffix)

    text[prefix.length, text.length - prefix.length - suffix.length]
  end
end
