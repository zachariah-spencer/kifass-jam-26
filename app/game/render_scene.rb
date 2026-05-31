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
    nearby_interactables.each { |interactable| interactable.render_highlight(args, args.outputs[:scene], @camera) unless input_locked? }
    current_enemies.each { |enemy| enemy.render(args, args.outputs[:scene], @camera) }
    @player.render(args, args.outputs[:scene], @camera, player_alpha)
    render_ambient_dust(args, args.outputs[:scene])
    args.outputs[:darkness].sprites << { x: 0, y: 0, w: Grid.w, h: Grid.h, path: :solid, r: 0, g: 0, b: 0, a: 255 }
    interactables.each { |interactable| interactable.render_light(args, args.outputs[:darkness], @camera) }
    current_enemies.each { |enemy| enemy.render_light(args, args.outputs[:darkness], @camera) }
    @player.render_light(args, args.outputs[:darkness], @camera, archive_off_path_light_multiplier)

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
