module Casseo
  class Runner
    def self.execute(args)
      new(args).execute
    end

    def initialize(args)
      @args = args
      @exit_message = nil
      setup_signals
    end

    def execute
      Curses.cbreak      # no need for a newline to get type chars
      Curses.curs_set(1) # invisible
      Curses.noecho      # don't echo character on a getch

      Curses.init_screen

      # fail fast on missing config
      Config.required

      load_dashboards

      if @args.count > 0 && File.exists?(File.expand_path(@args.first))
        eval(File.read(@args.first)).run
      elsif @args.count > 0 && ["-l", "--list"].include?(@args.first)
        @exit_message = Dashboard.index.sort.join("\n")
      elsif @args.first
        Dashboard.run(@args.first.to_sym)
      else
        Dashboard.run(Config.dashboard_default)
      end
    rescue ConfigError, DashboardNotFound => e
      @exit_message = e.message
    ensure
      Curses.close_screen
      puts @exit_message if @exit_message
    end

    private

    def load_dashboards
      dir = "#{File.expand_path("~")}/.casseo/dashboards"
      if File.exists?(dir)
        # clever hack to get symlinks working properly
        Dir["#{dir}/**{,/*/**}/*.rb"].each do |d|
          require d
        end
      end
    end

    def setup_signals
      ["TERM", "INT"].each do |s|
        Signal.trap(s) do
          @exit_message = "Caught deadly signal"
          Kernel.exit(0)
        end
      end
    end
  end
end
