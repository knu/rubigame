# -*- coding: utf-8 -*-
$KCODE = 'u'

require 'rubigame/util'

module RubiGame
  class GameBoard
    module Recordable
      RECORDING_METHODS = []

      def self.recording_method(method)
        RECORDING_METHODS << method
      end

      def self.included(base)
        base.class_exec(RECORDING_METHODS) { |recording_methods|
          recording_methods.each { |method|
            alias_method_chain method, :recording
          }
        }
      end

      def initialize_with_recording(*args)
        initialize_without_recording(*args)
        @initial_board = create_new(Board)
        @moves = []
        @pos = 0
        @unrecorded = false
      end

      recording_method :initialize

      def record(move)
        return if @unrecorded
        @moves[@pos] = move
        @pos += 1
        @moves.slice!(@pos..-1)
      end

      def unrecorded(&block)
        saved = @unrecorded
        @unrecorded = true
        block.call
      ensure
        @unrecorded = saved
      end

      def shuffle_with_recording
        ret = shuffle_without_recording
        each_of_all { |x, y, color|
          @initial_board[x, y] = color
        }
        @moves.clear
        @pos = 0
        ret
      end

      recording_method :shuffle

      def shoot_with_recording
        if has_aimed?
          x, y, color = each_aimed.first
          record([x, y])
        end
        shoot_without_recording
      end

      recording_method :shoot

      def restart
        clear
        @initial_board.each_of_all { |x, y, color|
          self[x, y] = color
        }
        @pos = 0
      end

      def re_do
        @pos <= @moves.size or raise "no more moves"
        x, y = @moves[@pos]
        aim(x, y)
        unrecorded {
          shoot
        }
        squeeze
        @pos += 1
        self
      end

      def undo
        @pos >= 1 or raise "no more moves"
        new_pos = @pos - 1
        restart
        re_do while @pos < new_pos
        self
      end
    end
  end
end
