module Flipped
  # Patterns replaced in the flip-book file name.
  module FlipBookPattern
    PATTERN = /%\w/
    CONTROLLER = '%c'
    PLAYER = '%p'
    DATE = '%d'
    TIME = '%t'
    STORY = '%s'
  end

  APP_NAME = 'Flipped'
  AUTHOR = 'Spooner'

  LOG_DIR = File.join(INSTALLATION_ROOT, 'logs')
  Dir.mkdir Flipped::LOG_DIR unless File.exists? Flipped::LOG_DIR
  LOG_FILE = File.open(File.join(LOG_DIR, 'flipped.log'), 'w')
  LOG_FILE.sync = true

  STDOUT_LOG_FILENAME = File.join(LOG_DIR, 'stdout.log')
  STDERR_LOG_FILENAME = File.join(LOG_DIR, 'stderr.log')

  DEFAULT_GAME_SCREEN_WIDTH = 640
  DEFAULT_GAME_SCREEN_HEIGHT = DEFAULT_GAME_SCREEN_WIDTH * 3 / 4
  DEFAULT_TIME_LIMIT = 30
  DEFAULT_FULL_SCREEN = false # Assume that if you are using Flipped, you want a window.
  DEFAULT_SID_DIRECTORY = File.expand_path(File.join(INSTALLATION_ROOT, '..'))
  DEFAULT_FLIPPED_PORT = 7776 # Leaves 7777 for data socket.
  DEFAULT_SID_PORT = 7778
  DEFAULT_FLIP_BOOK_PATTERN = "'#{FlipBookPattern::STORY}' (#{FlipBookPattern::CONTROLLER} - #{FlipBookPattern::PLAYER}) #{FlipBookPattern::DATE} #{FlipBookPattern::TIME}"
  DEFAULT_TEMPLATE_DIR = File.join(INSTALLATION_ROOT, 'templates')
  DEFAULT_NAME = 'User'
  DEFAULT_STORY_NAME = 'Story'

  SETTINGS_ATTRIBUTES = {
    :window_x => ['x', 100],
    :window_y => ['y', 100],
    :window_width => ['width', 800],
    :window_height => ['height', 800],

    :current_flip_book_directory => ['@current_flip_book_directory', Dir.pwd],
    :template_directory => ['@template_directory', DEFAULT_TEMPLATE_DIR],

    :slide_show_interval => ['slide_show_interval', 5],
    :slide_show_loops => ['slide_show_loops', false],

    :mouse_wheel_inverted => ['@mouse_wheel_inverted', false],

    :navigation_buttons_shown => ['@navigation_buttons_shown', true],
    :information_bar_shown => ['@information_bar_shown', true],
    :status_bar_shown => ['@status_bar_shown', true],
    :thumbnails_shown => ['@thumbnails_shown', true],

    :spectate_port => ['@spectate_port', DEFAULT_FLIPPED_PORT],
    :sid_port => ['@sid_port', DEFAULT_SID_PORT],
    :flip_book_pattern => ['@flip_book_pattern', DEFAULT_FLIP_BOOK_PATTERN],

    :user_name => ['@user_name', DEFAULT_NAME],
    :story_name => ['@story_name', DEFAULT_STORY_NAME],
    :hard_to_quit_mode => ['@hard_to_quit_mode', false],

    :player_time_limit => ['@player_time_limit', DEFAULT_TIME_LIMIT],
    :player_screen_width => ['@player_screen_width', DEFAULT_GAME_SCREEN_WIDTH],
    :player_screen_height => ['@player_screen_height', DEFAULT_GAME_SCREEN_HEIGHT],
    :player_full_screen => ['@player_full_screen', DEFAULT_FULL_SCREEN],
    :player_sid_directory => ['@player_sid_directory', DEFAULT_SID_DIRECTORY],

    :controller_address => ['@controller_address', ''],
    :controller_time_limit => ['@controller_time_limit', DEFAULT_TIME_LIMIT],
    :controller_screen_width => ['@controller_screen_width', DEFAULT_GAME_SCREEN_WIDTH],
    :controller_screen_height => ['@controller_screen_height', DEFAULT_GAME_SCREEN_HEIGHT],
    :controller_full_screen => ['@controller_full_screen', DEFAULT_FULL_SCREEN],
    :controller_sid_directory => ['@controller_sid_directory', DEFAULT_SID_DIRECTORY],

    :notification_sound => ['@notification_sound', File.join(INSTALLATION_ROOT, 'media', 'sounds', 'shortbeeptone.wav')],
    :notification_enabled => ['@notification_enabled', true],
  }

  KEYS_ATTRIBUTES = {
    # File
    :open => ['@key[:open]', 'Ctrl-O'],
    :append => ['@key[:append]', 'Ctrl-A'],
    :save_as => ['@key[:save_as]', 'Ctrl-S'],
    :quit => ['@key[:quit]', 'Ctrl-Q'],

    # SleepIsDeath
    :play_sid => ['@key[:play_sid]', 'Ctrl-P'],
    :control_sid => ['@key[:control_sid]', 'Ctrl-N'],
    :spectate_sid => ['@key[:spectate_sid]', 'Ctrl-P'],

    # Navigation
    :start => ['@key[:start]', 'Home'],
    :previous => ['@key[:previous]', 'Left'],
    :play => ['@key[:play]', 'Space'],
    :next => ['@key[:next]', 'Right'],
    :end => ['@key[:end]', 'End'],

    # View
    :toggle_nav_buttons_bar => ['@key[:toggle_nav_buttons_bar]', 'Ctrl-B'],
    :toggle_status_bar => ['@key[:toggle_status_bar]', 'Ctrl-U'],
    :toggle_thumbs => ['@key[:toggle_thumbs]', 'Ctrl-T'],
    :toggle_info => ['@key[:toggle_info]', 'Ctrl-I'],

    :view_half_size => ['@key[:view_half_size]', 'Ctrl-2'],
    :view_original_size => ['@key[:view_original_size]', 'Ctrl-3'],
    :view_double_size => ['@key[:view_double_size]', 'Ctrl-4'],

    :toggle_looping => ['@key[:loops]', 'Ctrl-L'],

    # Edit
    :delete_single => ['@key[:delete_single]', 'Ctrl-X'],
    :delete_before => ['@key[:delete_before]', ''],
    :delete_after => ['@key[:delete_after]', ''],
    :delete_identical => ['@key[:delete_identical]', 'Ctrl-Shift-X'],
  }
end