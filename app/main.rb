require_relative "rendering.rb"
require_relative "camera.rb"
require_relative "entities.rb"
require_relative "game.rb"
require_relative "scenes.rb"
require_relative "root_scene.rb"

$root_scene = nil

def tick args
  $root_scene ||= RootScene.new
  $root_scene.args = args
  $root_scene.tick
end

def reset args
  $root_scene = nil
end

DR.reset
