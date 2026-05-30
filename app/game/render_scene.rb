class Game
  def render args
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
    nearby_interactables.each { |interactable| interactable.render_highlight(args, args.outputs[:scene], @camera) unless input_locked? }
    @enemy.render(args, args.outputs[:scene], @camera) if @enemy.room_id == @current_room_id
    @player.render(args, args.outputs[:scene], @camera, player_alpha)
    render_ambient_dust(args, args.outputs[:scene])
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    @enemy.render_light(args, args.outputs[:darkness], @camera) if @enemy.room_id == @current_room_id
    @player.render_light(args, args.outputs[:darkness], @camera)

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

  def render_ambient_dust args, outputs = args.outputs
    visible = {
      x: @camera.x,
      y: @camera.y,
      w: @camera.visible_w,
      h: @camera.visible_h
    }
    min_col = (visible[:x] / DUST_PARTICLE_CELL_SIZE).floor
    max_col = ((visible[:x] + visible[:w]) / DUST_PARTICLE_CELL_SIZE).ceil
    min_row = (visible[:y] / DUST_PARTICLE_CELL_SIZE).floor
    max_row = ((visible[:y] + visible[:h]) / DUST_PARTICLE_CELL_SIZE).ceil
    tick = Kernel.tick_count

    dust = []
    (min_col..max_col).each do |col|
      (min_row..max_row).each do |row|
        seed = dust_particle_seed(col, row)
        next unless seed % 100 < DUST_PARTICLE_DENSITY_PERCENT

        particle = ambient_dust_particle(col, row, seed, tick)
        screen_rect = @camera.screen_rect(particle)
        next if screen_rect[:x] < -6 || screen_rect[:x] > Grid.w + 6
        next if screen_rect[:y] < -6 || screen_rect[:y] > Grid.h + 6

        dust << screen_rect.merge(
          path: :solid,
          r: 255,
          g: 255,
          b: 255,
          a: particle[:a]
        )
      end
    end
    outputs.primitives << dust
  end

  def ambient_dust_particle col, row, seed, tick
    phase = seed % 360
    slow_phase = (tick + phase) * Math::PI * 2 / 420
    fast_phase = (tick + phase * 3) * Math::PI * 2 / 260
    base_x = col * DUST_PARTICLE_CELL_SIZE + seed % DUST_PARTICLE_CELL_SIZE
    base_y = row * DUST_PARTICLE_CELL_SIZE + seed.idiv(7) % DUST_PARTICLE_CELL_SIZE
    drift_y = (tick * (0.012 + (seed % 7) * 0.002)) % DUST_PARTICLE_CELL_SIZE
    size = seed % 5 == 0 ? 10 : 8
    alpha = DUST_PARTICLE_ALPHA_MIN + seed % (DUST_PARTICLE_ALPHA_MAX - DUST_PARTICLE_ALPHA_MIN)

    {
      x: base_x + Math.sin(slow_phase) * 18 + Math.sin(fast_phase) * 5,
      y: base_y + Math.cos(slow_phase) * 12 + drift_y,
      w: size,
      h: size,
      a: (alpha + Math.sin(fast_phase) * 18).to_i.clamp(DUST_PARTICLE_ALPHA_MIN, DUST_PARTICLE_ALPHA_MAX)
    }
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
