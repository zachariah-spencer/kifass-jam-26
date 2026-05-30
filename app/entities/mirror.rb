class Mirror < Interactable
  W = WorldScale.value(54)
  H = WorldScale.value(74)

  def initialize x, y, id
    super(x, y, W, H, id: id, word: "MIRROR")
  end

  def interaction_text
    "A cold reflection shows paths the floor refuses to keep."
  end

  def sacrificed_interaction_text
    "The frame holds only dust-dark glass."
  end

  def render args, outputs = args.outputs, camera = nil
    mirror_rect = camera ? camera.screen_rect(rect) : rect
    outputs.sprites << Render.solid(mirror_rect, sacrificed? ? :wall : :void, a: 225)
    outputs.borders << mirror_rect.merge(**Render.color(sacrificed? ? :ash : :brass), a: 220)

    glass = {
      x: mirror_rect[:x] + 10,
      y: mirror_rect[:y] + 10,
      w: mirror_rect[:w] - 20,
      h: mirror_rect[:h] - 20
    }
    outputs.sprites << Render.solid(glass, sacrificed? ? :stone : :ash, a: sacrificed? ? 80 : 58)
    outputs.borders << glass.merge(**Render.color(:ash), a: sacrificed? ? 70 : 140)
  end
end
