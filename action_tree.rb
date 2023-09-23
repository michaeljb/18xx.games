require 'engine'

# Array of Hashes, all actions in the game
# game.raw_actions

# Array of Actions, only processed actions; undone actions are pruned
# game.actions

# filename = '33867.json'  # 1822 fixture with undo action_id and redo

filename = 'hs_ypmxafwv_1695321744.json'  # new 1846 2p hotseat

@game = Engine::Game.load(filename)


# @actions is a Hash; contains all actions except messages
#   key: action id
#   value: action hash, with added keys 'parent', 'children', 'branch'
#
# 'parent' and 'children' used for the tree structure (each action is a node
#  with a single parent and 0-to-many children)
#
# 'branch' is an integer value; 0 is the 'real' branch, other branch nums are
# branches which were abandoned via undos
prev_action = nil
branch_num = 0
@actions = @game.raw_actions.each_with_object({}) do |original_action, action_tree|
  # dup to avoid bad mutations on actual game state
  action = original_action.dup

  # ignore chat messages
  next if action['type'] == 'message'

  id = action['id']

  # tmp, look at only first N actions
  next if id > 14

  # add current action to the tree, linking it to its parent action
  action['branch'] = 0
  action['children'] = []
  action['parent'] = nil
  if prev_action
    action['parent'] = prev_action['id']
    prev_action['children'] << id
  end
  action_tree[id] = action

  if action['type'] == 'undo'
    # id of last action which was not undone
    prev_id = action['action_id'] || prev_action['parent']

    # undoing creates a new branch
    branch_num += 1
    branch = branch_num
    action['branch'] = branch

    # TODO: track active undos; if undoing multiple things they should all be on
    # one branch, only the undos need their own unique branches
    #
    # move undone actions to new branch; actions which are already branched
    # don't need to branch again
    parent_id = action['parent']
    until parent_id == prev_id
      parent_action = action_tree[parent_id]
      parent_action['branch'] = branch
      parent_id = parent_action['parent']
    end

    prev_action = action_tree[prev_id]
  else
    prev_action = action
  end
end

def print_action_tree(action_tree)
  len = action_tree.keys.max.to_s.size

  action_tree.each do |id, a|
    # hide undo actions, they are uninteresting to see in the tree
    # next if a['type'] == 'undo'

    puts " #{'  ' * a['branch']}%#{len}s   "\
         "b:%2s   "\
         "p:%#{len}s   "\
         "c:%-#{(2*len)+4}s   "\
         "e:#{a['entity']}   "\
         "a:#{a['type']}"\
         "" % [id, a['branch'], a['parent'], a['children'].to_s]
  end

  # don't show a return value in irb console
  nil
end

@len = @actions.keys.max.to_s.size

def print_action_t(action_tree, a, level: 0)
  len = @len

  action_str =
    if a['type'] == 'undo' && a.include?('action_id')
      "#{a['type']}(#{a['action_id']})"
    else
      a['type']
    end

  #unless %w[undo redo].include?(a['type'])
  puts "b:%2s   "\
       " #{'  ' * level}%#{len}s   "\
       "p:%#{len}s   "\
       "c:%-#{(2*len)+4}s   "\
       "e:#{a['entity']}   "\
       "a:#{action_str}"\
       "" % [a['branch'], a['id'], a['parent'], a['children'].to_s]

  a['children'].sort_by { |id| action_tree[id]['branch'] == a['branch'] ? 1 : 0 }.each do |id|
    child = action_tree[id]

    l = level +
        if child['branch'] != a['branch']
          1
        else
          0
        end
    print_action_t(action_tree, child, level: l)
  end


  # don't show a return value in irb console
  nil
end

# this is crap
def print_action_crap(action, level: 0)
  prefix =
    if level.zero?
      ''
    else
      "%4s #{' ' * (level-1)}" % '|'
    end

  puts "#{prefix}%4s -- p:#{action['parent']} -- c:#{action['children'].to_s} -- "\
       "#{action['entity']}: #{action['type']}" % action['id']

  case action['children'].size
  when 1
    puts "#{' ' * level}   |"
    next_action = @actions[action['children'].first]
    print_action(next_action, level: level)
  when 2
    puts "#{' ' * level}   |\\"
    puts "#{' ' * level}   | \\"
    puts "#{' ' * level}   |  \\"
    puts "#{' ' * level}   |   \\"

    next_action = @actions[action['children'].last]
    print_action(next_action, level: level + 1)

    next_action = @actions[action['children'].first]
    print_action(next_action, level: level)
  end

  # don't show a return value in irb console
  nil
end
