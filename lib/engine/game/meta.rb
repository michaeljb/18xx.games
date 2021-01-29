module Engine
  module Game
    module Meta
      DEV_STAGES = %i[production beta alpha prealpha].freeze
      DEV_STAGE = :prealpha

      GAME_LOCATION = nil
      GAME_PUBLISHER = nil

      PLAYER_RANGE = nil

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def <=>(other)
          [DEV_STAGES.index(self::DEV_STAGE), title.sub(/18\s+/, '18').downcase] <=>
            [DEV_STAGES.index(other::DEV_STAGE), other.title.sub(/18\s+/, '18').downcase]
        end

        def title
          parts = name.split('::')
          last = parts.last
          penultimate = parts[-2]
          ((last == 'Game' || last == 'Meta') ? penultimate : last).slice(1..-1)
        end
      end
    end
  end
end
