class Room
  attr_reader :id, :world_w, :world_h, :play_area, :player_spawns, :interactables, :barriers

  def initialize id, world_w, world_h, play_area, player_spawns, interactables, barriers = []
    @id = id
    @world_w = world_w
    @world_h = world_h
    @play_area = play_area
    @player_spawns = player_spawns
    @interactables = interactables
    @barriers = barriers
  end

  def spawn spawn_id
    @player_spawns[spawn_id] || @player_spawns[:default]
  end
end
