# frozen_string_literal: true

require './spec/spec_helper'

require 'find'
require 'json'

# run all games found in spec/fixtures/, verify that the engine gets the result
# indicated in the game's "result" key in the JSON
module Engine
  Find.find(FIXTURES_DIR).select { |f| File.basename(f) =~ /.json/ }.each do |fixture|
    game_title = File.basename(File.dirname(fixture))
    filename = File.basename(fixture)
    game_id = filename.split('.json').first
    describe game_title do
      context game_id do
        before(:all) do
          @text = File.read(fixture)
          @data = JSON.parse(@text)
        end

        describe "formatted with `rake fixture_format[\"#{game_id}\"]`" do
          it 'text is compressed' do
            expect(@text.lines.size).to eq(1)
          end

          it 'game descriptions and player names are removed' do
            @data['players'].each do |player|
              expect(player['name']).to match(/^(Player )?(\d+|[A-Z])$/)
            end

            if @data.dig('fixture_format', 'keep_user')
              expect(@data['players']).to include(@data['user'])
            else
              expect(@data['user']).to eq({ 'id' => 0, 'name' => 'You' })
            end

            expect(@data['description']).to eq('') unless @data.dig('fixture_format', 'keep_description')
          end

          it 'has no chat messages' do
            expect(@data['actions'].count { |a| a['type'] == 'message' && a['message'] != 'chat' }).to eq(0)
          end

          it 'is loaded and finished' do
            # this is required for opening fixtures in the browser at /fixture/<title>/<id>
            expect(@data['loaded']).to eq(true)
            expect(@data['status']).to eq('finished')
          end

          it 'all actions have an Integer id' do
            @data['actions'].each.with_index do |action, index|
              expect(action['id']).to(
                be_kind_of(Integer),
                "Expected action at index #{index} to be an Integer instead of #{action['id']}."
              )
            end
          end

          it 'player scores are Integers' do
            @data['result'].each do |player, score|
              expect(score).to(
                be_kind_of(Integer),
                "Expected stored JSON score #{score} for player '#{player}' to be an Integer",
              )
            end
          end
        end

        [false, true].each do |strict|
          describe "with strict: #{strict}" do
            describe 'running full game' do
              before(:all) do
                @game = Engine::Game.load(@data, strict: strict).maybe_raise!
              end

              it 'is finished and matches result exactly' do
                result = @data['result']

                game_result = JSON.parse(JSON.generate(@game.result))
                expect(game_result).to eq(result)
                expect(@game.finished).to eq(true)
              end

              it "last N actions in game match fixture's test_last_actions" do
                test_last_actions = @data['test_last_actions']
                next unless test_last_actions

                actions = @data['actions']
                (1..(test_last_actions.to_i)).each do |index|
                  run_action = @game.actions[@game.actions.size - index].to_h
                  expect(run_action).to eq(actions[actions.size - index])
                end
              end

              it 'all expected cash is accounted for' do
                starting_cash = @game.bank_starting_cash

                ending_cash = @game.spenders.compact.map(&:spender).uniq.sum(&:cash)

                expect(ending_cash).to be_kind_of(Integer)
                expect(ending_cash).to eq(starting_cash)
              end
            end

            # # this block can be quite expensive even for a single fixture, so
            # # its best use is to identify exactly at which action something
            # # breaks in a particular fixture, running `rspec` with
            # # `--fail-fast` and `-e` for a game that fails one of the above
            # # tests
            # describe 'validated at every action' do
            #   @game = Engine::Game.load(@data, strict: strict, at_action: 0).maybe_raise!
            #   starting_cash = @game.bank_starting_cash
            #   [@data['actions']].each do |action|
            #     @game.process_to_action(action['id'])
            #     # use a URL here to easily open up the game in the browser for
            #     # inspection when a test fails
            #     describe "http://localhost:9292/fixture/#{@game.class.title}/#{@game_id}?action=#{action['id']}" do
            #       it "total cash is consistent" do
            #         cash = @game.spenders.compact.map(&:spender).uniq.sum(&:cash)
            #         expect(cash).to eq(starting_cash)
            #       end
            #       it 'integer money' do
            #         [@game.bank, *@game.players, *@game.corporations].each do |entity|
            #           expect(entity.cash).to be_kind_of(Integer)
            #         end
            #       end
            #     end
            #   end
            # end
          end
        end
      end
    end
  end
end
