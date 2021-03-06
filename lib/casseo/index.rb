module Casseo
  module Index
    @@index = {}

    def define(name)
      dashboard = Dashboard.new(name)
      yield(dashboard)
      @@index[name] = dashboard
      dashboard
    end

    def index
      @@index.keys
    end

    def run(name)
      if @@index.key?(name)
        @@index[name].run
      else
        raise DashboardNotFound.new("#{name} is not a known dashboard")
      end
    end
  end

  class DashboardNotFound < StandardError
  end
end
