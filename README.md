Casseo
======

A Graphite dashboard viewable without ever leaving the command line. Configuration and concept very similar to [Tasseo](tasseo).

Install via Rubygems:

    gem install casseo

Or if you're really concerned about Rubygems' speed, clone the reposistory and create a standalone version (Ruby 1.9 satisfies all of Casseo's dependencies):

    git clone https://github.com/brandur/casseo.git
    cd casseo
    rake standalone
    mv casseo ~/bin/casseo

Configuration
-------------

Casseo expects to be able to find your Graphite credentials at `~/.casseorc`:

    echo '{ graphite_auth: "graphite:my_secret_api_key", graphite_url: "https://graphite.example.com:8080" }' > ~/.casseorc
    chmod 600 ~/.casseorc

Other allowed configuration options are:

* `compressed_chart:` whether to include a space between chart symbols
* `dashboard_default:` name of the dashboard to load if none is specified
* `interval:` Graphite update interval in seconds

Dashboards
----------

Dashboards are configured via simple Ruby in a manner reminiscent of Tasseo. All `*.rb` files in `~/.casseo/dashboards` or in any of its subdirectories are loaded automatically. Dashboards are assigned names so that they can be referenced and opened like so:

    casseo home

An example dashboard (save to `~/.casseo/dashboards/home.rb`):

``` ruby
Casseo::Dashboard.define(:api) do |d|
  d.metric "custom.api.production.requests.per-sec", display: "req/sec"
  d.blank
  d.metric "custom.api.production.requests.500.per-min", display: "req 500/min"
  d.metric "custom.api.production.requests.502.per-min", display: "req 502/min"
  d.metric "custom.api.production.requests.503.per-min", display: "req 503/min"
  d.metric "custom.api.production.requests.504.per-min", display: "req 504/min"
  d.blank
  d.metric "custom.api.production.requests.user-errors.per-min", display: "req user err/min"
  d.blank
  d.metric "custom.api.production.requests.latency.avg", display: "req latency"
end
```

Get a list of all known dashboards:

    casseo --list

Casseo also takes a file as its first parameter:

    casseo ~/.casseo/dashboards/home.rb

Key Bindings
------------

For now, there are no options on key bindings. Here's what you get:

* `j` page down
* `k` page up
* `q` quit
* `1` 5 minute range
* `2` 60 minute range
* `3` 3 hour range
* `4` 24 hour range
* `5` 7 day range

[tasseo]: https://github.com/obfuscurity/tasseo
