module Casseo
  module Config
    extend self

    # whether an extra space is inserted between chart characters
    def compressed_chart
      !!config(:compressed_chart)
    end

    def dashboard_default
      config(:dashboard_default) || :home
    end

    # show extra decimal precision
    def decimal_precision
      config(:decimal_precision) || 1
    end

    def graphite_auth
      config!(:graphite_auth)
    end

    def graphite_url
      config!(:graphite_url)
    end

    # seconds
    def interval
      config(:interval) || 2.0
    end

    # minutes
    def period_default
      config(:period_default) || 5
    end

    def required
      [ Casseo::Config.graphite_auth,
        Casseo::Config.graphite_url ]
    end

    private

    def casseorc
      @@casseorc ||= eval(File.read(File.expand_path("~/.casseorc")))
    end

    def config(sym)
      casseorc[sym]
    end

    def config!(sym)
      casseorc[sym] or raise ConfigError.new(":#{sym} not found in ~/.casseorc")
    end
  end

  class ConfigError < StandardError
  end
end
