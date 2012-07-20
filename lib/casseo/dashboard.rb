# encoding: utf-8

module Casseo
  class Dashboard
    CHART_CHARS = [" "] + %w(▁ ▂ ▃ ▄ ▅ ▆ ▇)

    extend Index

    def initialize(name="")
      init_colors

      @confs = []
      @compressed_chart = Config.compressed_chart
      @data = nil
      @decimal_precision = Config.decimal_precision
      @name = name
      @page = 0
      @period = Config.period_default # minutes
      @show_max = false
    end

    def blank
      @confs << nil
    end

    def metric(metric, conf = {})
      @confs << conf.merge(metric: metric)
    end

    def run
      @longest_display = @confs.compact.
        map { |c| c[:display] || c[:metric] }.map { |c| c.length }.max
      @num_metrics = @confs.compact.count

      # no data yet, but force drawing of stats to the screen
      show(true)

      Thread.new do
        # one initial fetch where we don't suppress errors so that the user can
        # verify that their credentials are right
        fetch(false)
        sleep(Config.interval)

        loop do
          fetch
          sleep(Config.interval)
        end
      end

      loop do
        show
        begin
          Timeout::timeout(Config.interval) do
            handle_key_presses
          end
        rescue Timeout::Error
        end
      end
    end

    private

    # color pairs
    NORMAL    = 0
    WARNING   = 1
    CRITICAL  = 2
    STATUS    = 3

    def clamp(n, min, max)
      if n < min
        min
      elsif n > max
        max
      else
        n
      end
    end

    def fetch(suppress_errors=true)
      metrics = @confs.compact.map { |c| c[:metric] }
      targets = metrics.map { |m| "target=#{URI.encode(m)}" }.join("&")
      uri = URI.parse("#{Config.graphite_url}/render/?#{targets}&" +
        "from=-#{@period}minutes&format=json")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(*Config.graphite_auth.split(":"))

      @data = begin
        response = http.request(request)
        JSON.parse(response.body)
      rescue
        raise unless suppress_errors
        nil
      end
    end

    def handle_key_presses
      loop do
        new_compressed_chart  = nil
        new_decimal_precision = nil
        new_page              = nil
        new_period            = nil
        new_show_max          = nil

        case Curses.getch
        when Curses::KEY_RESIZE then show
        when ?c then new_compressed_chart = !@compressed_chart
        when ?j then new_page = clamp(@page + 1, 0, num_pages)
        when ?k then new_page = clamp(@page - 1, 0, num_pages)
        when ?m then new_show_max = !@show_max
        when ?p then new_decimal_precision = @decimal_precision == 3 ?
          Config.decimal_precision : 3
        when ?q then Kernel.exit(0)
        when ?1 then new_period = 5
        when ?2 then new_period = 60
        when ?3 then new_period = 60 * 3
        when ?4 then new_period = 60 * 24
        when ?5 then new_period = 60 * 24 * 7
        end

        if new_compressed_chart != nil
          @compressed_chart = new_compressed_chart
          Curses.clear
          show
        end

        if new_page && new_page != @page
          @page = new_page
          Curses.clear
          show
        end

        if new_show_max != nil
          @show_max = new_show_max
          Curses.clear
          show
        end

        if new_decimal_precision && new_decimal_precision != @decimal_precision
          @decimal_precision = new_decimal_precision
          Curses.clear
          show
        end

        if new_period && new_period != @period
          @period = new_period
          # will update the next time the fetch loop runs
        end
      end
    end

    def init_colors
      Curses.start_color
      Curses.use_default_colors

      Curses.init_pair(1, Curses::COLOR_YELLOW, -1)
      Curses.init_pair(2, Curses::COLOR_RED,    -1)
      Curses.init_pair(3, Curses::COLOR_GREEN,  Curses::COLOR_BLUE)
    end

    def num_lines
      # -1 for the status line
      Curses.lines - 1
    end

    def num_pages
      (@confs.count / num_lines).ceil
    end

    def show(force_draw=false)
      # force us through the method
      @data = @data || [] if force_draw

      # failed to fetch on this cycle
      return unless @data

      @confs.each_with_index do |conf, i|
        next unless conf
        next unless i >= @page * num_lines && i < (@page + 1) * num_lines

        data_points = @data.detect { |d| d["target"] == conf[:metric] }
        data_points = data_points ? data_points["datapoints"].dup : []

        # show left to right latest to oldest
        data_points.reverse!

        max = data_points.select { |p| p[0] != nil }.
          max { |p1, p2| p1[0] <=> p2[0] }
        max = max ? max[0] : nil

        # keep everything under a very small threshold at 0 bars
        max = 0.0 if max && max < 0.01

        latest = data_points.detect { |p| p[0] != nil }
        latest = latest ? latest[0] : 0.0

        unit = conf[:unit] || " "
        float_width = 7 + @decimal_precision
        str = "%-#{@longest_display}s %#{float_width}.#{@decimal_precision}f%s " %
          [conf[:display] || conf[:metric], latest, unit]
        str += "%#{float_width}.#{@decimal_precision}f%s " %
          [max || 0.0, unit] if @show_max

        chart = ""
        if max && max > 0
          num_samples = Curses.cols - str.length
          (1..num_samples).each do |i|
            next if i % 2 == 0 unless @compressed_chart
            index = ((i.to_f / num_samples.to_f) * data_points.count.to_f).to_i - 1
            sample = data_points[index][0]
            sample = 0.0 unless sample

            index = (sample / max * CHART_CHARS.count).to_i - 1
            chart += CHART_CHARS[index]
            chart += " " unless @compressed_chart
          end
        end

        str += chart
        str = str[0...Curses.cols]

        color_pair = if conf[:critical] && latest >= conf[:critical]
          CRITICAL
        elsif conf[:warning] && latest >= conf[:warning]
          WARNING
        else
          NORMAL
        end

        Curses.setpos(i % num_lines, 0)
        Curses.attron(Curses::color_pair(color_pair) | Curses::A_NORMAL) do
          Curses.addstr(str)
        end
      end

      show_status
      Curses.refresh
    end

    def format_period(seconds)
      case true
      when seconds < 60    then "#{seconds}s"
      when seconds < 3600  then "#{seconds / 60}m"
      when seconds < 86400 then "#{seconds / 3600}h"
      else "#{seconds / 86400}d"
      end
    end

    def show_status
      Curses.setpos(num_lines, 0)
      Curses.attron(Curses::color_pair(STATUS) | Curses::A_NORMAL) do
        str = "Casseo: =%s   (%s)   [Metrics:%s Interval:%ss]" %
          [@name, format_period(@period * 60), @num_metrics, Config.interval.to_i]
        page_str = "--- %s/%s ---" % [@page, num_pages]

        # right align the page number
        str += "%#{Curses.cols - str.length}s" % page_str

        Curses.addstr(str)
      end
    end
  end
end
