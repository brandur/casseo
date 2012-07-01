# encoding: utf-8

module Casseo
  class Dashboard
    CHART_CHARS = [" "] + %w(▁ ▂ ▃ ▄ ▅ ▆ ▇)

    extend Index

    def initialize
      @confs = []
      @data = nil
      @page = 0
      @period = Config.period_default # minutes
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
      uri = URI.parse("#{Config.graphite_url}/render/?#{targets}&from=-#{@period}minutes&format=json")

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
        new_page   = nil
        new_period = nil

        case Curses.getch
        when Curses::KEY_RESIZE then show
        when ?j then new_page = clamp(@page + 1, 0, num_pages)
        when ?k then new_page = clamp(@page - 1, 0, num_pages)
        when ?q then Kernel.exit(0)
        when ?1 then new_period = 5
        when ?2 then new_period = 60
        when ?3 then new_period = 60 * 3
        when ?4 then new_period = 60 * 24
        when ?5 then new_period = 60 * 24 * 7
        end

        if new_page && new_page != @page
          @page = new_page
          Curses.clear
          show
        end

        if new_period && new_period != @period
          @period = new_period
          # will update the next time the fetch loop runs
        end
      end
    end

    def num_pages
      (@confs.count / Curses.lines).ceil
    end

    def show(force_draw=false)
      # force us through the method
      @data = @data || [] if force_draw

      # failed to fetch on this cycle
      return unless @data

      @confs.each_with_index do |conf, i|
        next unless conf
        next unless i >= @page * Curses.lines && i < (@page + 1) * Curses.lines

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
        str = "%-#{@longest_display}s %8.1f%s " %
          [conf[:display] || conf[:metric], latest, unit]

        chart = ""
        if max && max > 0
          num_samples = Curses.cols - str.length
          (1..num_samples).each do |i|
            next if i % 2 == 0 unless Config.compressed_chart
            index = ((i.to_f / num_samples.to_f) * data_points.count.to_f).to_i - 1
            sample = data_points[index][0]
            sample = 0.0 unless sample

            index = (sample / max * CHART_CHARS.count).to_i - 1
            chart += CHART_CHARS[index]
            chart += " " unless Config.compressed_chart
          end
        end

        str += chart
        str = str[0...Curses.cols]
        Curses.setpos(i % Curses.lines, 0)
        Curses.addstr(str)
      end
      Curses.refresh
    end
  end
end
