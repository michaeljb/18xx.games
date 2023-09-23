require 'engine'

# Array of Hashes, all actions in the game
# game.raw_actions

# Array of Actions, only processed actions; undone actions are pruned
# game.actions

# filename = '33867.json'  # 1822 fixture with undo action_id and redo

filename = 'hs_ypmxafwv_1695321744.json'  # new 1846 2p hotseat

@game = Engine::Game.load(filename)

@undoing_branch = nil
@active_undos = []

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
@active_branch = 0
@actions = @game.raw_actions.each_with_object({}) do |original_action, action_tree|
  # dup to avoid bad mutations on actual game state
  action = original_action.dup

  # ignore chat messages
  next if action['type'] == 'message'

  id = action['id']

  # tmp, look at only first N actions
  # n = 28
  # next if id > n

  # add current action to the tree, linking it to its parent action
  if action['type'] != 'redo'
    action['branch'] = 0
    action['children'] = []
    action['parent'] = nil
    if prev_action
      action['parent'] = prev_action['id']
      prev_action['children'] << id
    end
  end
  action_tree[id] = action

  case action['type']
  when 'undo'
    @active_undos << action['id']

    # id of last action which was not undone
    prev_id = action['action_id'] || prev_action['parent']

    # undoing creates a new branch; undoing multiple actions consecutively only
    # creates branches for the undo actions
    branch_num += 1
    branch = branch_num
    unless @undoing_branch
      @undoing_branch = branch_num
    end
    action['branch'] = branch

    # move undone actions to new branch; actions which are already branched
    # don't need to branch again
    parent_id = action['parent']
    until parent_id == prev_id
      parent_action = action_tree[parent_id]
      parent_action['branch'] = @undoing_branch
      parent_id = parent_action['parent']
    end

    prev_action = action_tree[prev_id]
  when 'redo'
    undo_id = @active_undos.pop
    @undoing_branch = nil if @active_undos.empty?

    # redo is a special case, the only action which can be the child of an undo
    action['parent'] = undo_id
    action['children'] = []
    undo_action = action_tree[undo_id]
    undo_action['children'] << action['id']
    undo_branch = undo_action['branch']
    action['branch'] = undo_branch

    # un-branch all actions on the branch that was created by the undo action
    parent_action = action_tree[undo_action['parent']]
    until parent_action['branch'] == 0
      parent_action['branch'] = @active_branch
      parent_action = action_tree[parent_action['parent']]
    end

    prev_action = action_tree[undo_action['parent']]
  else
    @active_undos.clear
    @undoing_branch = nil
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

def print_action_t(action_tree, a, level: 0, show_undo: false)
  len = @len

  action_str =
    if a['type'] == 'undo' && a.include?('action_id')
      "#{a['type']}(#{a['action_id']})"
    else
      a['type']
    end

  should_render =
    if %w[undo redo].include?(a['type'])
      show_undo
    else
      true
    end

  if should_render
    puts "b:%2s   "\
         " #{'  ' * level}%#{len}s   "\
         "p:%#{len}s   "\
         "c:%-#{(2*len)+4}s   "\
         "e:#{a['entity']}   "\
         "a:#{action_str}"\
         "" % [a['branch'], a['id'], a['parent'], a['children'].to_s]
  end

  puts "\n" if show_undo && a['children'] && a['children'].empty?

  (a['children'] || []).sort_by { |id| action_tree[id]['branch'] == a['branch'] ? 1 : 0 }.each do |id|
    child = action_tree[id]

    l = level +
        if child['branch'] != a['branch']
          1
        else
          0
        end
    print_action_t(action_tree, child, level: l, show_undo:show_undo)
  end


  # don't show a return value in irb console
  nil

  if a['id'] == 1
    puts "\nactive_undos = #{@active_undos}\n\n"
    puts "\nundoing_branch = #{@undoing_branch}\n\n"
  end
end
