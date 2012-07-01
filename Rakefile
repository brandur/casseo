task :standalone do
  skeleton = File.read("./bin/casseo")

  # same require order as lib/casseo.rb
  source_files = [
    "./lib/casseo/config",
    "./lib/casseo/index",
    "./lib/casseo/dashboard",
    "./lib/casseo/runner",
    "./lib/casseo/version",
  ]

  source = source_files.map { |f| File.read("#{f}.rb") }.join("\n")
  source = skeleton.gsub(
    /# @@STANDALONE_START@@.*# @@STANDALONE_END@@\n\n/m, source)

  target = "./casseo"
  File.open(target, 'w') do |f|
    f.puts source
    f.chmod 0755
  end
  puts "Saved to #{target}"
end
