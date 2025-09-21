# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :games, :game_end_reason, String, null: true, default: nil
  end
end
