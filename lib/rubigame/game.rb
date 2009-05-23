# -*- coding: utf-8 -*-
$KCODE = 'u'

require 'rubygems'
require 'pathname'
require 'sdl'
require 'rubigame/util'
require 'rubigame/gameboard'
require 'rubigame/gameboard/scorable'
require 'rubigame/gameboard/recordable'

module RubiGame
  class Game < GameBoard
    module GUI
      BOARD_TOP_MARGIN = 8
      BOARD_BOTTOM_MARGIN = 8
      BOARD_LEFT_MARGIN = 8
      BOARD_RIGHT_MARGIN = 8

      CELL_SIZE = 32
      STATUSBAR_WIDTH = 250
      STATUSBAR_HEIGHT = 24

      BASE_DIR = Pathname(__FILE__).dirname.parent.parent
      IMAGES_DIR = BASE_DIR + 'images'
      FONTS_DIR = BASE_DIR + 'fonts'

      attr_reader :screen

      RENDERING_METHODS = []

      def self.rendering_method(method)
        RENDERING_METHODS << method
      end

      def self.included(base)
        base.class_exec(RENDERING_METHODS) { |rendering_methods|
          include RubiGame::GameBoard::Recordable
          include RubiGame::GameBoard::Scorable

          rendering_methods.each { |method|
            alias_method_chain method, :rendering
          }
        }
      end

      def create_image(width, height, &block)
        SDL::Surface.new(SDL::SWSURFACE, width, height, @screen).tap { |image|
          yield image if block
        }
      end

      def create_piece(colorno)
        picture = SDL::Surface.load('%s/piece%d.png' % [IMAGES_DIR, colorno])
        [
          create_image(CELL_SIZE, CELL_SIZE) { |image|
            image.put(picture, 0, 0)
            image.set_color_key(SDL::SRCCOLORKEY, [0, 0, 0])
          },
          create_image(CELL_SIZE, CELL_SIZE) { |image|
            image.put(picture, 0, 0)
            image.set_color_key(SDL::SRCCOLORKEY, [0, 0, 0])
            image.set_alpha(SDL::SRCALPHA, 0x80)
          }
        ]
      end

      def initialize_with_rendering(width, height, ncolors)
        initialize_without_rendering(width, height, ncolors)

        @unrendered = false

        @screen_width = [
          BOARD_LEFT_MARGIN + CELL_SIZE * width + BOARD_RIGHT_MARGIN,
          STATUSBAR_WIDTH,
        ].max
        @screen_height = BOARD_TOP_MARGIN + CELL_SIZE * height + BOARD_BOTTOM_MARGIN +
          STATUSBAR_HEIGHT

        @board_left = BOARD_LEFT_MARGIN
        @board_bottom = BOARD_TOP_MARGIN + CELL_SIZE * height

        @statusbar_left = BOARD_LEFT_MARGIN
        @statusbar_top = @board_bottom + BOARD_BOTTOM_MARGIN

        SDL.init(SDL::INIT_EVERYTHING)
        SDL::WM.set_caption('RubiGame', '')
        @screen = SDL.set_video_mode(@screen_width, @screen_height, 16,
          SDL::HWSURFACE | SDL::DOUBLEBUF)

        @piece_images = (0...@ncolors).map { |colorno|
          create_piece(colorno)
        }

        @bg_image = create_image(CELL_SIZE, CELL_SIZE) { |image|
          image.fill_rect(0, 0, CELL_SIZE, CELL_SIZE, [0x33, 0x33, 0x33])
        }

        @curtain_image = create_image(CELL_SIZE * width, CELL_SIZE * height) { |image|
          image.fill_rect(0, 0, CELL_SIZE * width, CELL_SIZE * height, [0, 0, 0])
          image.set_alpha(SDL::SRCALPHA, 0x80)
        }

        SDL::TTF.init
        @score_font = SDL::TTF.open(File.join(FONTS_DIR, "LiberationMono-Italic.ttf"), 16)
        @message_font = SDL::TTF.open(File.join(FONTS_DIR, "LiberationSerif-BoldItalic.ttf"), 24)
      end

      rendering_method :initialize

      def cell_topleft(x, y)
        [@board_left + CELL_SIZE * x, @board_bottom - CELL_SIZE * (y + 1)]
      end

      def render
        @screen.fill_rect(0, 0, @screen.w, @screen.h, [0, 0, 0])

        each_of_all { |x, y, value|
          left, top = cell_topleft(x, y)
          @screen.put(@bg_image, left, top)

          case value
          when 0...@ncolors
            @screen.put(@piece_images[value][aimed?(x, y) ? 1 : 0], left, top)
          end
        }

        if has_aimed?
          @score_font.draw_blended_utf8(@screen, "Score: %d  Aim: %d" % [score, temp_score],
            @statusbar_left, @statusbar_top, 0xff, 0xff, 0xff)
        else
          @score_font.draw_blended_utf8(@screen, "Score: %d" % score,
            @statusbar_left, @statusbar_top, 0xff, 0xff, 0xff)
        end

        if empty?
          put_message("Cleared!")
        elsif !has_aimable?
          put_message("Game Over")
        end

        @screen.flip unless @unrendered
      end

      def put_message(text)
        text_width, text_height = @message_font.text_size(text)
        @screen.put(@curtain_image, BOARD_LEFT_MARGIN, BOARD_TOP_MARGIN)
        @message_font.draw_blended_utf8(@screen, text,
          BOARD_LEFT_MARGIN + (CELL_SIZE * @width - text_width) / 2,
          BOARD_TOP_MARGIN + (CELL_SIZE * @height - text_height) / 2, 0xff, 0xff, 0xff)
      end

      def unrendered(&block)
        saved = @unrendered
        @unrendered = true
        block.call
      ensure
        @unrendered = saved
      end

      def self.render_after(target)
        eval %{
          def #{target}_with_rendering(*args)
            *ret = unrendered {
              #{target}_without_rendering(*args)
            }
            render
            return *ret
          end
        }
        rendering_method target
      end

      render_after :shuffle
      render_after :aim
      render_after :shoot
      render_after :squeeze
      render_after :re_do
      render_after :undo

      def get_event
        if event = SDL::Event2.poll
          case event
          when SDL::Event2::Quit 
            return :quit
          when SDL::Event2::KeyDown
            case event.sym
            when SDL::Key::BACKSPACE, SDL::Key::LEFT
              return :undo
            when SDL::Key::RIGHT
              return :redo
            when SDL::Key::SPACE
              return :new
            when SDL::Key::ESCAPE
              return :quit
            end
          when SDL::Event2::MouseButtonUp
            case event.button
            when SDL::Mouse::BUTTON_LEFT
              if !has_aimable?
                return :new
              end
              x = (event.x - BOARD_LEFT_MARGIN) / CELL_SIZE
              y = (height - 1) - (event.y - BOARD_TOP_MARGIN) / CELL_SIZE
              if index?(x, y) && filled?(x, y)
                return [x, y]
              end
            when SDL::Mouse::BUTTON_MIDDLE
              return :new
            when SDL::Mouse::BUTTON_RIGHT
              return :undo
            end
          end
        end
        return nil
      end

      def loop_with_wait(ticks_per_cycle, &block)
        loop {
          ticks_start = SDL.getTicks
          block.call
          ticks_wait = ticks_per_cycle - (SDL.getTicks - ticks_start)
          if ticks_wait > 0
            sleep ticks_wait / 1000.0
          end
        }
      end

      def play
        shuffle

        loop_with_wait(20) {
          case input = get_event
          when :new
            shuffle
          when :quit
            break
          when :undo
            undo rescue nil
          when :redo
            re_do rescue nil
          when Array
            x, y = input
            if aimed?(x, y)
              shoot
              squeeze
            elsif aimable?(x, y)
              aim(x, y)
            end
          end
        }
      end
    end

    include GUI
  end
end
