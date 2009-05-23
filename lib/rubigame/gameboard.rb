# -*- coding: utf-8 -*-
$KCODE = 'u'

module RubiGame
  class Board
    attr_reader :width, :height

    def initialize(width, height)
      @width = width
      @height = height

      @files = Array.new(@width) { [] }
    end

    def initialize_copy(orig)
      @width = orig.width
      @height = orig.height

      @files = orig.instance_eval {
        @files.map { |file|
          file.dup
        }
      }
    end

    def initialize_nocopy(orig)
      initialize(orig.width, orig.height)
    end
    private :initialize_nocopy

    def create_new(board_class = self.class)
      orig = self
      board_class.allocate.tap { |board|
        board.instance_eval {
          initialize_nocopy(orig)
        }
      }
    end

    def [](x, y)
      index?(x, y) or raise IndexError
      @files[x][y]
    end

    def []=(x, y, value)
      index?(x, y) or raise IndexError
      @files[x][y] = value
    end

    def index?(x, y)
      0 <= x && x < @width && 0 <= y && y < @height
    end

    def filled?(x, y)
      !@files[x][y].nil?
    end

    def clear
      @files.each { |file|
        file.clear
      }
    end

    def each_of_all
      block_given? or return to_enum(__method__)

      @files.each.with_index { |file, x|
        (0...@height).each { |y|
          yield [x, y, file[y]]
        }
      }
      self
    end

    def each
      block_given? or return to_enum(__method__)

      @files.each.with_index { |file, x|
        file.each.with_index { |value, y|
          yield [x, y, value] if filled?(x, y)
        }
      }
      self
    end

    include Enumerable

    def empty?
      each { return false }
      return true
    end
  end

  class CheckerBoard < Board
    def filled?(x, y)
      !!@files[x][y]
    end
  end

  class GameBoard < Board
    attr_reader :ncolors

    def initialize(width, height, ncolors)
      super(width, height)
      @ncolors = ncolors
      @aim = create_new(CheckerBoard)
      @aim_count = 0
    end

    def initialize_copy(orig)
      super
      @ncolors = orig.ncolors
      @aim = orig.instance_eval { @aim.dup }
      @aim_count = orig.aim_count
    end

    def initialize_nocopy(orig)
      initialize(orig.width, orig.height, orig.ncolors)
    end

    def clear
      @aim.clear
      @aim_count = 0
      super
    end

    def shuffle
      clear
      @files.each { |file|
        file.fill(0...@height) {
          rand(@ncolors)
        }
      }
      self
    end

    def mark_aimable(x, y)
      index?(x, y) or raise IndexError

      unaim
      mark(x, y, self[x, y])
    end

    def aim(x, y)
      mark_aimable(x, y)

      if @aim_count >= 2
        @aim_count
      else
        unaim
        nil
      end
    end

    def aimable?(x, y)
      mark_aimable(x, y)

      aimable = @aim_count >= 2
      unaim
      aimable
    end

    def aimed?(x, y)
      @aim.filled?(x, y)
    end

    attr_reader :aim_count

    def has_aimed?
      @aim_count > 0
    end

    def unaim
      @aim.clear
      @aim_count = 0
    end

    def mark(x, y, color)
      @aim[x, y].nil? or return

      if @aim[x, y] = (self[x, y] == color)
        @aim_count += 1
        mark(x - 1, y, color) if 0 < x
        mark(x + 1, y, color) if x < @width - 1
        mark(x, y - 1, color) if 0 < y
        mark(x, y + 1, color) if y < @height - 1
      end
    end
    private :mark

    def each_aimed
      block_given? or return to_enum(__method__)

      @aim.each { |x, y, bool|
        yield x, y, self[x, y]
      }
      self
    end

    def has_aimable?
      if has_aimed?
        return true
      end
      each { |x, y, value|
        if aimable?(x, y)
          return true
        end
      }
      false
    end

    def shoot
      if has_aimed?
        each_aimed { |x, y, value|
          self[x, y] = nil
        }
        @aim_count
      else
        nil
      end
    end

    def squeeze
      @files.reject! { |file|
        file.reject! { |color| color.nil? }
        file.empty?
      }

      @files.fill((@files.size)...@width) { [] }
      unaim
      self
    end
  end
end
