# frozen_string_literal: true

require 'find'

def raw_action(game, action_index)
  game.instance_variable_get(:@raw_all_actions)[action_index]
end

# Returns the loaded Game object at the specified action_id for the fixture
# as described by the class structure. The tests need to be structured like this:
#
# module Engine
#   module Game
#     describe #{GameClass} do
#       describe #{fixture_id} do
#
#         # optionally have more nested describe blocks here
#
#         it 'does something'
#           game = fixture_at_action(123)
#
#           # do stuff with the game state here
#         end
#
#       end
#     end
#   end
# end
def fixture_at_action(action_id = 1, first_action_of_type:)
  group_descriptions = group_descriptions(RSpec.current_example)

  game_title = Object.const_get(group_descriptions[-1]).const_get('Meta').title
  fixture_id = group_descriptions[-2]

  game_file =
    Find.find("#{FIXTURES_DIR}/#{game_title}").find { |f| File.basename(f) == "#{fixture_id}.json" }

  if first_action_of_type
    action_id = find_first_action_of_type(first_action_of_type, game_file)
  end

  Engine::Game.load(game_file, at_action: action_id).maybe_raise!
end

def group_descriptions(test)
  descriptions = []
  group = test.metadata[:example_group]
  until group.nil?
    descriptions << group[:description]
    group = group[:parent_example_group]
  end
  descriptions
end

def find_first_action_of_type(action_type, game_file)
  data = JSON.parse(File.read(game_file))
  action = data['actions'].find { |a| a['type'] == action_type }
  action ? action['id'] - 1 : 1
end
