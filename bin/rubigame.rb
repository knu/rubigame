#!/usr/bin/env ruby

require 'pathname'
$LOAD_PATH.unshift Pathname(__FILE__).dirname.parent + 'lib'

require 'rubigame'

RubiGame::Game.new(8, 8, 4).play
