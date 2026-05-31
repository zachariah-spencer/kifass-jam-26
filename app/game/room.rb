class Room
  attr_reader :id, :world_w, :world_h, :play_area, :player_spawns, :interactables, :barriers, :safe_paths, :locked_gates

  def initialize id, world_w, world_h, play_area, player_spawns, interactables, barriers = [], options = nil
    options ||= {}
    @id = id
    @world_w = world_w
    @world_h = world_h
    @play_area = play_area
    @player_spawns = player_spawns
    @interactables = interactables
    @barriers = barriers
    @safe_paths = options[:safe_paths] || []
    @locked_gates = options[:locked_gates] || []
  end

  def spawn spawn_id
    @player_spawns[spawn_id] || @player_spawns[:default]
  end
end
