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

          it 'players are anonymized' do
            @data['players'].each do |player|
              expect(player['name']).to match(/^(Player )?(\d+|[A-Z])$/)
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
                "Expected action at index #{index} to be an Integer instead of #{action['id'].to_s}."
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

              it 'matches test_last_actions' do
                # some fixtures want to test that the last N actions of the game replayed the same as in the fixture
                test_last_actions = @data['test_last_actions']
                next unless test_last_actions

                actions = @data['actions']
                (1..(test_last_actions.to_i)).each do |index|
                  run_action = @game.actions[@game.actions.size - index].to_h
                  expect(run_action).to eq(actions[actions.size - index])
                end
              end

              it 'all expected cash is accounted for' do
                expected_cash =
                  case (bank_cash = @game.init_bank_cash)
                  when Integer
                    bank_cash
                  when Hash
                    bank_cash[@game.players.size]
                  end

                cash = @game.spenders.compact.map(&:spender).uniq.sum(&:cash)

                expect(cash).to be_kind_of(Integer)
                expect(cash).to eq(expected_cash)
              end
            end

            it 'validated at every action' do
              game = Engine::Game.load(@data, strict: strict, at_action: 0).maybe_raise!
              expected_cash =
                case (bank_cash = game.init_bank_cash)
                when Integer
                  bank_cash
                when Hash
                  bank_cash[game.players.size]
                end


              [{'id' => 0 }, *@data['actions']].each do |action|
                game.process_to_action(action['id'])

                # total cash
                cash = game.spenders.compact.map(&:spender).uniq.sum(&:cash)
                expect(cash).to(
                  eq(expected_cash),
                  "actual: #{cash}, expected: #{expected_cash}\n"\
                  "http://localhost:9292/fixture/#{game.class.title}/#{game_id}?action=#{action['id']}",
                )

                # integer money
                [game.bank, *game.players, *game.corporations].each do |entity|
                  expect(entity.cash).to(
                    be_kind_of(Integer),
                    "Expected entity \"#{entity.name}\" cash #{entity.cash} to be an Integer at "\
                    "action #{action}\n"\
                    "http://localhost:9292/fixture/#{game.class.title}/#{game_id}?action=#{action['id']}",
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
