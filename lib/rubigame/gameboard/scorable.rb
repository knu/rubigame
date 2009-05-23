# -*- coding: utf-8 -*-
$KCODE = 'u'

require 'rubigame/util'

module RubiGame
  class GameBoard
    module Scorable
      attr_reader :score
      attr_reader :temp_score

      SCORING_METHODS = []

      def self.scoring_method(method)
        SCORING_METHODS << method
      end

      def self.included(base)
        base.class_exec(SCORING_METHODS) { |scoring_methods|
          scoring_methods.each { |method|
            alias_method_chain method, :scoring
          }
        }
      end

      def initialize_with_scoring(*args)
        initialize_without_scoring(*args)
        @score = 0
        @temp_score = 0
      end

      scoring_method :initialize

      def clear_with_scoring
        @score = 0
        @temp_score = 0
        clear_without_scoring
      end

      scoring_method :clear

      def aim_with_scoring(*args)
        if aim_count = aim_without_scoring(*args)
          @temp_score = (aim_count - 2) ** 2
        else
          @temp_score = 0
        end
        aim_count
      end

      scoring_method :aim

      def unaim_with_scoring
        unaim_without_scoring
        @temp_score = 0
      end

      scoring_method :unaim

      def shoot_with_scoring
        if ret = shoot_without_scoring
          @score += @temp_score
          if empty?
            @score += width * height * ncolors
          end
          @temp_score = 0
        end
        ret
      end

      scoring_method :shoot
    end
  end
end
