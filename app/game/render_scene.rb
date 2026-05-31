class Game
  def render args
    if level_editor_active?
      render_level_editor(args)
      return
    end

    if ending_card_screen?
      render_ending_card_background(args)
    else
      render_lit_scene(args)
    end
    render_ui(args)
    render_ending(args)
    render_room_transition(args)
    render_reset_sequence(args)
  end

  def ending_card_screen?
    return false unless ending_sequence_triggered?

    [
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
  end

  def render_ending_card_background args
    args.outputs.sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
  end

  def render_lit_scene args
    args.outputs[:scene].set(w: Grid.w, h: Grid.h, background_color: [10, 9, 14, 255])
    args.outputs[:darkness].set(w: Grid.w, h: Grid.h, background_color: [0, 0, 0, 0])

    render_floor(args, args.outputs[:scene])
    render_room_barriers(args, args.outputs[:scene])
    render_archive_safe_paths(args, args.outputs[:scene])
    interactables.each { |interactable| render_interactable(args, interactable, args.outputs[:scene]) }
    render_bell_ring_pulses(args.outputs[:scene])
    nearby_interactables.each { |interactable| interactable.render_highlight(args, args.outputs[:scene], @camera) unless input_locked? }
    current_enemies.each { |enemy| enemy.render(args, args.outputs[:scene], @camera) }
    @player.render(args, args.outputs[:scene], @camera, player_alpha)
    render_ambient_dust(args, args.outputs[:scene])
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    current_enemies.each { |enemy| enemy.render_light(args, args.outputs[:darkness], @camera) }
    lamp_effect = learned_word_effect("LAMP", LEARNED_LAMP_EFFECT_FRAMES)
    if lamp_effect
      render_lamp_power_up_player_light(args.outputs[:darkness], lamp_effect)
    elsif @player_light_size_effect
      render_player_light_size_effect(args.outputs[:darkness])
    else
      @player.render_light(args, args.outputs[:darkness], @camera, archive_off_path_light_multiplier)
    end
    render_lamp_power_up_lights(args.outputs[:scene], args.outputs[:darkness], lamp_effect)

    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :scene }
    args.outputs.primitives << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :darkness }
  end

  def render_interactable args, interactable, outputs
    if interactable.is_a?(FinalDoor)
      interactable.render(args, outputs, @camera, final_door_open?)
    else
      interactable.render(args, outputs, @camera)
    end
  end

  def archive_off_path_light_multiplier
    return 1.0 unless archive_off_path_warning_active?

    pulse = Math.sin(Kernel.tick_count * Math::PI * 2 / 10)
    (0.66 + pulse * 0.14).clamp(0.5, 1.0)
  end

  def render_lamp_power_up_lights scene_outputs, darkness_outputs, effect
    return unless effect

    progress = effect[:progress]
    strength = 1.0 - progress
    bloom = Math.sin(progress * Math::PI)
    player_center = @camera.screen_point(@player.center)
    player_light_size = lamp_power_up_player_light_size(effect)
    render_teal_lamp_bloom(scene_outputs, player_center, player_light_size, (170 * strength).to_i)

    visible = camera_world_rect(384)
    interactables.each do |interactable|
      next unless interactable.is_a?(Lamp)
      next unless rects_intersect?(interactable.rect, visible)

      light_center = @camera.screen_point(interactable.center)
      light_size = Lamp::LIGHT_SIZE.lerp(Lamp::LIGHT_SIZE + 520, bloom) * @camera.zoom
      render_teal_lamp_bloom(scene_outputs, light_center, light_size, (145 * strength).to_i)
      darkness_outputs.sprites << light_center.merge(
        path: "sprites/mask.png",
        w: light_size,
        h: light_size,
        anchor_x: 0.5,
        anchor_y: 0.5,
        a: (210 * strength).to_i,
        blendmode: Render::HOLE_PUNCH_BLENDMODE
      )
    end
  end

  def render_teal_lamp_bloom outputs, center, size, alpha
    outputs.sprites << center.merge(
      path: "sprites/mask.png",
      w: size,
      h: size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 255,
      g: 255,
      b: 0,
      a: alpha
    )
  end

  def render_lamp_power_up_player_light outputs, effect
    light_center = @camera.screen_point(@player.center)
    light_size = lamp_power_up_player_light_size(effect) * archive_off_path_light_multiplier
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 255,
      g: 255,
      b: 0,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def render_player_light_size_effect outputs
    progress = effect_progress(@player_light_size_effect[:started_at], @player_light_size_effect[:duration])
    unless progress
      @player_light_size_effect = nil
      @player.render_light(nil, outputs, @camera, archive_off_path_light_multiplier)
      return
    end

    light_center = @camera.screen_point(@player.center)
    from_size = player_light_render_size(@player_light_size_effect[:from_size])
    to_size = player_light_render_size(@player_light_size_effect[:to_size])
    light_size = from_size.lerp(to_size, progress) * archive_off_path_light_multiplier
    outputs.sprites << light_center.merge(
      path: "sprites/mask.png",
      w: light_size,
      h: light_size,
      anchor_x: 0.5,
      anchor_y: 0.5,
      blendmode: Render::HOLE_PUNCH_BLENDMODE
    )
  end

  def lamp_power_up_player_light_size effect
    progress = effect[:progress]
    from_size = player_light_render_size(effect[:previous_player_light_size] || @player.light_size)
    to_size = player_light_render_size(effect[:learned_player_light_size] || @player.light_size)
    in_progress = LEARNED_LAMP_EFFECT_IN_FRAMES.to_f / LEARNED_LAMP_EFFECT_FRAMES
    if progress <= in_progress
      local_progress = (progress / in_progress).clamp(0, 1)
      from_size.lerp(LEARNED_LAMP_PEAK_LIGHT_SIZE, local_progress)
    else
      local_progress = ((progress - in_progress) / (1.0 - in_progress)).clamp(0, 1)
      LEARNED_LAMP_PEAK_LIGHT_SIZE.lerp(to_size, local_progress)
    end
  end

  def player_light_render_size base_size
    @player.oscillating_light_size(base_size, Player::LIGHT_OSCILLATION_AMOUNT)
  end

  def render_bell_ring_pulses outputs
    return if @bell_ring_pulses.empty?

    @bell_ring_pulses.reject! do |pulse|
      progress = effect_progress(pulse[:started_at], BELL_RING_PULSE_FRAMES)
      next true unless progress

      center = @camera.screen_point(pulse)
      radius = 30.lerp(1500, progress) * @camera.zoom
      alpha = (220 * (1.0 - progress)).to_i
      ring = {
        x: center[:x] - radius,
        y: center[:y] - radius,
        w: radius * 2,
        h: radius * 2
      }
      outputs.borders << ring.merge(r: 255, g: 255, b: 255, a: alpha)
      outputs.borders << ring.merge(x: ring[:x] + 4, y: ring[:y] + 4, w: ring[:w] - 8, h: ring[:h] - 8, r: 255, g: 188, b: 86, a: (alpha * 0.65).to_i)
      false
    end
  end

  def learned_word_effect_progress word, duration
    effect = learned_word_effect(word, duration)
    effect && effect[:progress]
  end

  def learned_word_effect word, duration
    effect = @learned_word_effects[word]
    return nil unless effect

    progress = effect_progress(effect[:started_at], duration)
    unless progress
      @learned_word_effects.delete(word)
      return nil
    end

    effect.merge(progress: progress)
  end

  def effect_progress started_at, duration
    progress = (Kernel.tick_count - started_at).to_f / duration
    return nil if progress >= 1.0

    progress.clamp(0, 1)
  end

  def camera_world_rect padding = 0
    {
      x: @camera.x - padding,
      y: @camera.y - padding,
      w: @camera.visible_w + padding * 2,
      h: @camera.visible_h + padding * 2
    }
  end

  def render_ambient_dust args, outputs = args.outputs
    cam_x = @camera.x
    cam_y = @camera.y
    zoom = Camera::ZOOM
    shake = @camera.shake_offset
    shake_x = shake[:x]
    shake_y = shake[:y]
    min_col = (cam_x / DUST_PARTICLE_CELL_SIZE).floor
    max_col = ((cam_x + @camera.visible_w) / DUST_PARTICLE_CELL_SIZE).ceil
    min_row = (cam_y / DUST_PARTICLE_CELL_SIZE).floor
    max_row = ((cam_y + @camera.visible_h) / DUST_PARTICLE_CELL_SIZE).ceil
    tick = Kernel.tick_count
    two_pi = Math::PI * 2

    @dust_particle_cells ||= {}
    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        particle = dust_particle_cell(col, row)
        next unless particle

        slow_phase = (tick + particle[:phase]) * two_pi / 420
        fast_phase = (tick + particle[:fast_phase]) * two_pi / 260
        drift_y = (tick * particle[:drift_speed]) % DUST_PARTICLE_CELL_SIZE
        x = (particle[:base_x] + Math.sin(slow_phase) * 18 + Math.sin(fast_phase) * 5 - cam_x) * zoom + shake_x
        y = (particle[:base_y] + Math.cos(slow_phase) * 12 + drift_y - cam_y) * zoom + shake_y
        next if x < -6 || x > Grid.w + 6
        next if y < -6 || y > Grid.h + 6

        outputs.primitives << {
          x: x,
          y: y,
          w: particle[:size] * zoom,
          h: particle[:size] * zoom,
          path: :solid,
          r: 255,
          g: 255,
          b: 255,
          a: (particle[:alpha] + Math.sin(fast_phase) * 18).to_i.clamp(DUST_PARTICLE_ALPHA_MIN, DUST_PARTICLE_ALPHA_MAX)
        }
      end
    end
  end

  def dust_particle_cell col, row
    @dust_particle_cells ||= {}
    key = (col << 32) ^ (row & 0xffffffff)
    return @dust_particle_cells[key] if @dust_particle_cells.key?(key)

    seed = dust_particle_seed(col, row)
    @dust_particle_cells[key] = if seed % 100 < DUST_PARTICLE_DENSITY_PERCENT
                                  phase = seed % 360
                                  {
                                    phase: phase,
                                    fast_phase: phase * 3,
                                    base_x: col * DUST_PARTICLE_CELL_SIZE + seed % DUST_PARTICLE_CELL_SIZE,
                                    base_y: row * DUST_PARTICLE_CELL_SIZE + seed.idiv(7) % DUST_PARTICLE_CELL_SIZE,
                                    drift_speed: 0.012 + (seed % 7) * 0.002,
                                    size: seed % 5 == 0 ? 10 : 8,
                                    alpha: DUST_PARTICLE_ALPHA_MIN + seed % (DUST_PARTICLE_ALPHA_MAX - DUST_PARTICLE_ALPHA_MIN)
                                  }
                                else
                                  false
                                end
  end

  def dust_particle_seed col, row
    ((col * 73_856_093) ^ (row * 19_349_663) ^ 83_492_791).abs
  end

  def final_door_open?
    return false unless ending_sequence_triggered?

    [
      :door_opens,
      :player_fades,
      :player_walks,
      :fade_black,
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
  end

  def player_alpha
    return 255 unless ending_sequence_triggered?
    return 0 if [
      :fade_black,
      :final_text_fade_in,
      :final_text,
      :final_text_fade_out,
      :title_fade_in,
      :title_card,
      :title_fade_out,
      :done
    ].include?(@ending_phase)
    return 255 unless @ending_phase == :player_fades

    (255 - ending_phase_elapsed * 210 / ENDING_PLAYER_FADE_FRAMES).clamp(45, 255)
  end
end
