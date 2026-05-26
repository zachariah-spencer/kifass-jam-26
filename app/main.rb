require "app/rendering.rb"
require "app/camera.rb"
require "app/entities.rb"
require "app/game.rb"
require "app/scenes.rb"
require "app/root_scene.rb"

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
