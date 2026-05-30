class NameAltar < Altar
  def interact game
    return "The altar is spent." if sacrificed?
    return "The final altar is cold. Two names must be taken first." unless game.sanctum_final_altar_active?

    game.open_altar(self)
  end

  def render args, outputs = args.outputs, camera = nil
    altar_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << altar_sprite(altar_rect).merge(Render.color(:ember))
  end

  def interaction_text
    return "The altar is spent." if sacrificed?

    "The final altar waits for the last name."
  end

end
