class Game
  def interaction_text_for interactable
    return nil unless interactable
    return interactable.sacrificed_interaction_text if interactable.word && @sacrificed_words.include?(interactable.word)
    return interactable.sacrificed_interaction_text if sacrificed_object?(interactable.id)
    return interactable.interaction_text unless interactable.word
    return interactable.interaction_text if @learned_object_ids.include?(interactable.id)

    first_learned_word = !@learned_words.include?(interactable.word)
    if first_learned_word
      @learned_words << interactable.word
      start_key_gate_animation(:open) if interactable.word == "KEY"
      @player.light_size = 2048 if interactable.id == :lamp
      show_mechanic_feedback(LEARNED_WORD_MESSAGES[interactable.word])
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

  def handle_altar_selection click
    word = altar_word_at(click)

    if word
      sacrifice_word(word)
    else
      close_altar
      set_interaction_text(nil)
    end
  end

  def sacrifice_word word
    return unless sacrificeable_words.include?(word)

    active_altar_id = @active_altar ? @active_altar.id : nil
    if player_name_word?(word)
      @camera.shake!
      @sacrificed_words << PLAYER_NAME_WORD unless @sacrificed_words.include?(PLAYER_NAME_WORD)
      @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
      @active_altar.sacrifice! if @active_altar
      close_altar
      set_interaction_text("You sacrificed #{word}.")
      start_ending_sequence
      return
    end

    @player.light_size = 1096 if word == "LAMP"
    start_key_gate_animation(:close) if word == "KEY"

    @learned_words.delete(word)
    @sacrificed_words << word unless @sacrificed_words.include?(word)
    @enemy.clear_stun! if word == "BELL"

    @learned_word_sources.delete(word)
    all_interactables.each do |interactable|
      next unless interactable.word == word

      @sacrificed_object_ids << interactable.id unless @sacrificed_object_ids.include?(interactable.id)
      interactable.sacrifice!
    end

    unlock_exits_for(active_altar_id)
    @sacrificed_object_ids << @active_altar.id if @active_altar && !@sacrificed_object_ids.include?(@active_altar.id)
    @active_altar.sacrifice! if @active_altar
    @camera.shake!
    close_altar
    show_mechanic_feedback(SACRIFICE_CONSEQUENCE_MESSAGES[word])
    set_interaction_text("You sacrificed #{word}.")
  end

  def show_mechanic_feedback text
    return unless text

    @mechanic_feedback_text = text
    @mechanic_feedback_until = Kernel.tick_count + MECHANIC_FEEDBACK_FRAMES
  end

  def unlock_exits_for altar_id
    return unless altar_id

    all_interactables.each do |interactable|
      next unless interactable.is_a?(Exit)
      next unless interactable.unlock_altar_id == altar_id

      interactable.unlock!
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
    SANCTUM_REGULAR_ALTAR_IDS.include?(altar.id)
  end

  def sanctum_regular_altar_spent_count
    SANCTUM_REGULAR_ALTAR_IDS.count { |altar_id| sacrificed_object?(altar_id) }
  end

  def sanctum_final_altar_active?
    sanctum_regular_altar_spent_count == SANCTUM_REGULAR_ALTAR_IDS.length
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
