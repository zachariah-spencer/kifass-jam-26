class Game
  def interaction_text_for interactable, args = nil
    return nil unless interactable
    return interactable.sacrificed_interaction_text if interactable.word && @sacrificed_words.include?(interactable.word)
    return interactable.sacrificed_interaction_text if sacrificed_object?(interactable.id)
    return interactable.interaction_text unless interactable.word
    return interactable.interaction_text if @learned_object_ids.include?(interactable.id)

    first_learned_word = !@learned_words.include?(interactable.word)
    if first_learned_word
      @learned_words << interactable.word
      previous_player_light_size = @player.light_size
      start_key_gate_animation(:open) if interactable.word == "KEY"
      @player.light_size = LEARNED_LAMP_LIGHT_SIZE if interactable.word == "LAMP"
      trigger_learned_word_effect(interactable.word, interactable, previous_player_light_size)
      show_mechanic_feedback(LEARNED_WORD_MESSAGES[interactable.word], args)
    end
    @learned_object_ids << interactable.id
    @learned_word_sources[interactable.word] = interactable.id

    "#{interactable.interaction_text} You remember that this is a #{interactable.word}."
  end

  def open_altar altar
    return "The altar is spent." if altar.sacrificed?

    @active_altar = altar
    @altar_open = true
    unless @altar_reinforcement_shown
      @altar_reinforcement_shown = true
      return ALTAR_REINFORCEMENT_TEXT
    end

    sacrificeable_words.empty? ? "The altar waits for a name." : "Choose a name to sacrifice."
  end

  def handle_altar_selection args, click
    word = altar_word_at(click)

    if word
      sacrifice_word(args, word)
    else
      close_altar
      set_interaction_text(nil)
    end
  end

  def sacrifice_word args, word
    return unless sacrificeable_words.include?(word)

    active_altar_id = @active_altar ? @active_altar.id : nil
    if player_name_word?(word)
      sacrifice_tick = Kernel.tick_count
      play_altar_crashing_sound(args)
      @camera.shake!(world_tick_count)
      @sacrificed_words << PLAYER_NAME_WORD unless @sacrificed_words.include?(PLAYER_NAME_WORD)
      seed_forgotten_word_corruptor(PLAYER_NAME_WORD)
      @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
      @active_altar.sacrifice!(sacrifice_tick) if @active_altar
      close_altar
      stop_music_for_final_sacrifice!
      start_ending_sequence
      set_interaction_text("You sacrificed #{word}.", slow: true)
      return
    end

    trigger_player_light_size_effect(@player.light_size, SACRIFICED_LAMP_LIGHT_SIZE, SACRIFICED_LAMP_EFFECT_FRAMES) if word == "LAMP"
    defer_post_mechanic_feedback_sfx(:altar_crashing)
    @player.light_size = SACRIFICED_LAMP_LIGHT_SIZE if word == "LAMP"
    start_key_gate_animation(:close) if word == "KEY"
    trigger_sacrifice_effect(word)

    @learned_words.delete(word)
    @sacrificed_words << word unless @sacrificed_words.include?(word)
    seed_forgotten_word_corruptor(word)
    if word == "BELL"
      defer_post_mechanic_feedback_sfx(:nameless, high_pitch: true)
      @enemies.each(&:clear_stun!)
      handle_bell_sacrifice_enemies!
    elsif word == "KEY"
      ensure_sanctum_enemy!
    end

    @learned_word_sources.delete(word)
    all_interactables.each do |interactable|
      next unless interactable.word == word

      @sacrificed_object_ids << interactable.id unless @sacrificed_object_ids.include?(interactable.id)
      interactable.sacrifice!(world_tick_count)
    end

    unlock_exits_for(active_altar_id)
    @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
    @active_altar.sacrifice!(world_tick_count) if @active_altar
    @camera.shake!(world_tick_count)
    close_altar
    show_mechanic_feedback(SACRIFICE_CONSEQUENCE_MESSAGES[word], args)
    set_interaction_text("You sacrificed #{word}.")
  end

  def defer_post_mechanic_feedback_sfx name, options = {}
    @post_mechanic_feedback_sfx ||= []
    @post_mechanic_feedback_sfx << { name: name, options: options }
  end

  def flush_post_mechanic_feedback_sfx args
    return if mechanic_feedback_freeze_active?
    return if !@post_mechanic_feedback_sfx || @post_mechanic_feedback_sfx.empty?

    pending_sfx = @post_mechanic_feedback_sfx
    @post_mechanic_feedback_sfx = []
    pending_sfx.each do |sfx|
      case sfx[:name]
      when :altar_crashing
        play_altar_crashing_sound(args)
      when :nameless
        play_nameless_sound(args, **sfx[:options])
      end
    end
  end

  def show_mechanic_feedback text, args = nil
    return unless text

    play_notification_sound(args) if args
    @mechanic_feedback_frozen_world_tick = world_tick_count
    @mechanic_feedback_freeze_started_at = Kernel.tick_count
    @mechanic_feedback_text = text
    @mechanic_feedback_started_at = Kernel.tick_count
    @mechanic_feedback_until = Kernel.tick_count + MECHANIC_FEEDBACK_FRAMES
    @mechanic_feedback_skip_progress = 0
    @mechanic_feedback_skip_hold_started_at = nil
    @mechanic_feedback_skip_hold_start_progress = 0
  end

  def trigger_learned_word_effect word, source, previous_player_light_size = nil
    @learned_word_effects[word] = {
      started_at: world_tick_count,
      source_id: source.id,
      previous_player_light_size: previous_player_light_size,
      learned_player_light_size: word == "LAMP" ? LEARNED_LAMP_LIGHT_SIZE : @player.light_size
    }
    add_bell_ring_pulse(source.center) if word == "BELL"
  end

  def trigger_sacrifice_effect word
    @sacrifice_effects[word] = { started_at: world_tick_count }
  end

  def seed_forgotten_word_corruptor word
    @forgotten_word_corruptors ||= {}
    @forgotten_word_corruptors[word] ||= TextCorruptor.new(word)
  end

  def sacrifice_effect word, duration
    effect = @sacrifice_effects[word]
    return nil unless effect

    progress = effect_progress(effect[:started_at], duration)
    unless progress
      @sacrifice_effects.delete(word)
      return nil
    end

    effect.merge(progress: progress)
  end

  def add_bell_ring_pulse center
    @bell_ring_pulses << {
      x: center[:x],
      y: center[:y],
      started_at: world_tick_count
    }
  end

  def trigger_player_light_size_effect from_size, to_size, duration
    @player_light_size_effect = {
      started_at: world_tick_count,
      from_size: from_size,
      to_size: to_size,
      duration: duration
    }
  end

  def unlock_exits_for altar_id
    return unless altar_id

    all_interactables.each do |interactable|
      next unless interactable.is_a?(Exit)
      next unless interactable.unlock_altar_id == altar_id

      interactable.unlock!(world_tick_count)
    end
  end

  def sacrificeable_words
    return sanctum_name_sacrifice_words if @active_altar && @active_altar.id == SANCTUM_FINAL_ALTAR_ID

    @learned_words
  end

  def sanctum_name_sacrifice_words
    sanctum_final_altar_active? ? [player_name_word] : []
  end

  def player_name_word
    @player_name.to_s.strip.empty? ? PLAYER_NAME_WORD : @player_name
  end

  def player_name_word? word
    word == PLAYER_NAME_WORD || word == player_name_word
  end

  def sanctum_regular_altar? altar
    sanctum_regular_altars.include?(altar)
  end

  def sanctum_regular_altar_spent_count
    sanctum_regular_altars.count(&:sacrificed?)
  end

  def sanctum_final_altar_active?
    altars = sanctum_regular_altars
    altars.length >= 2 && altars.all?(&:sacrificed?)
  end

  def sanctum_regular_altars
    room = @rooms[:sanctum]
    return [] unless room

    room.interactables.find_all { |interactable| interactable.is_a?(Altar) && !interactable.is_a?(NameAltar) }
  end

  def sacrificed_object? object_id
    @sacrificed_object_ids.include?(object_id)
  end

  def all_interactables
    objects = []
    @rooms.each_value do |room|
      room.interactables.each { |interactable| objects << interactable }
    end
    objects
  end

  def close_altar
    @altar_open = false
    @active_altar = nil
  end

  def close_altar_if_player_left_range
    return unless @altar_open && @active_altar
    return if nearby_interactable?(@active_altar)

    close_altar
    clear_interaction_text
  end

  def altar_word_at point
    sacrificeable_words.each_with_index do |word, index|
      return word if point_inside_rect?(point, altar_word_rect(index))
    end

    nil
  end

  def altar_word_rect index
    {
      x: ALTAR_PANEL[:x] + 32,
      y: ALTAR_PANEL[:y] + ALTAR_PANEL[:h] - 114 - index * ALTAR_WORD_ROW_H,
      w: ALTAR_PANEL[:w] - 64,
      h: 34
    }
  end

  def point_inside_rect? point, rect
    point_x = point.is_a?(Hash) ? point[:x] : point.x
    point_y = point.is_a?(Hash) ? point[:y] : point.y
    point_x >= rect[:x] && point_x <= rect[:x] + rect[:w] && point_y >= rect[:y] && point_y <= rect[:y] + rect[:h]
  end

  def handle_exit_transition
    exit = nearby_interactables.find { |interactable| interactable.is_a?(Exit) && rects_intersect?(@player.rect, interactable.rect) }
    text = exit&.interact(self)
    set_interaction_text(text) if text && text != @interaction_text
  end

  def rects_intersect? first, second
    first[:x] < second[:x] + second[:w] &&
      first[:x] + first[:w] > second[:x] &&
      first[:y] < second[:y] + second[:h] &&
      first[:y] + first[:h] > second[:y]
  end

  def distance_between first, second
    dx = second[:x] - first[:x]
    dy = second[:y] - first[:y]
    Math.sqrt(dx * dx + dy * dy)
  end

end
