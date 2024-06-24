# frozen_string_literal: true

require './spec/spec_helper'

module Engine
  module BfsGraph
    describe FifoQueue do

      describe '#empty?' do
        it 'returns true for an empty queue' do
          q = described_class.new([])
          expect(q.empty?).to eq(true)
        end

        it 'returns false for a populated queue' do
          q = described_class.new([1, 2, 3])
          expect(q.empty?).to eq(false)
        end

        it 'returns true for an emptied queue' do
          q = described_class.new([1, 2, 3])
          q.dequeue
          q.dequeue
          q.dequeue
          expect(q.empty?).to eq(true)
        end
      end

      describe 'peek' do
        it 'returns nil for an empty queue' do
          q = described_class.new([])
          expect(q.peek).to eq(nil)
        end

        it 'returns the front value for a populated queue without modifying the queue' do
          q = described_class.new([1, 2, 3])
          expect(q.peek).to eq(1)
          expect(q.peek).to eq(1)
        end
      end

      describe 'enqueue' do
        it 'inserts an item to the back of the queue' do
          q = described_class.new([1,2,3])
          expect(q.peek).to eq(1)

          q.enqueue(4)

          array = q.instance_variable_get(:@array)
          back = q.instance_variable_get(:@back)

          expect(array[back][described_class::ELEMENT]).to eq(4)
        end

        it 'inserts an item to the back and front of an empty queue' do
          q = described_class.new([])
          expect(q.peek).to eq(nil)

          q.enqueue(1)
          expect(q.peek).to eq(1)
        end
      end

      describe 'dequeue' do
        it 'removes the item from the front of the queue and returns it' do
          q = described_class.new([1, 2, 3])
          expect(q.peek).to eq(1)

          item = q.dequeue
          expect(item).to eq(1)

          expect(q.peek).to eq(2)
        end
      end

      describe 'to_s' do
        it 'returns string representation of the internal array' do
          q = described_class.new([1, 2, 3])
          expect(q.dequeue).to eq(1)
          q.enqueue(4)

          array = q.instance_variable_get(:@array)

          expect(q.dequeue).to eq(2)
          q.enqueue(5)

          expect(q.to_s).to eq("[[1, 4], [nil, 5], [0, 3]]")
        end
      end

      it 'reuses indices which have been dequeued' do
        q = described_class.new([1, 2, 3])
        expect(q.dequeue).to eq(1)

        empty_indices = q.instance_variable_get(:@empty_indices)
        expect(empty_indices).to eq([0])

        array = q.instance_variable_get(:@array)
        expect(array[0]).to eq(nil)
        expect(array.size).to eq(3)

        q.enqueue(4)
        expect(array[0]).to eq([nil, 4])
        expect(array.size).to eq(3)
        expect(empty_indices).to eq([])

        expect(q.peek).to eq(2)
      end

      describe 'each' do
        it 'iterates over elements in enqueued order, not in stored order' do
          q = described_class.new([1, 2, 3])
          expect(q.dequeue).to eq(1)
          q.enqueue(4)

          array = q.instance_variable_get(:@array)

          expect(q.dequeue).to eq(2)
          q.enqueue(5)

          expect(array[0]).to eq([1, 4])
          expect(array[1]).to eq([nil, 5])
          expect(array[2]).to eq([0, 3])

          result = []
          q.each { |i| result << i }
          expect(result).to eq([3, 4, 5])
        end

        it 'iterates in enqueued order for other Enumerable methods' do
          q = described_class.new([1, 2, 3])
          expect(q.dequeue).to eq(1)
          q.enqueue(4)

          array = q.instance_variable_get(:@array)

          expect(q.dequeue).to eq(2)
          q.enqueue(5)

          expect(array[0]).to eq([1, 4])
          expect(array[1]).to eq([nil, 5])
          expect(array[2]).to eq([0, 3])

          expect(q.map(&:to_s)).to eq(%w[3 4 5])
        end
      end
    end
  end
end
