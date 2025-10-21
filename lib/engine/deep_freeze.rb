# frozen_string_literal: true

class Object
  def deep_freeze
    if is_a?(Hash)
      each do |key, val|
        key.deep_freeze
        val.deep_freeze
      end
    elsif respond_to?(:each)
      each(&:deep_freeze)
    end
    freeze
  end

  def deep_frozen?
    return false unless frozen?

    if is_a?(Hash)
      all? do |key, val|
        key.deep_frozen?
        val.deep_frozen?
      end
    elsif respond_to?(:all?)
      all?(&:deep_frozen?)
    else
      true
    end
  end
end
