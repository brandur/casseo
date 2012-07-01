task :standalone do
  # lib/casseo.rb knows the correct load order
  source_files = File.read("./lib/casseo.rb").
    scan(/require_relative "(.*)"/).map { |f| "./lib/#{f.first}.rb" }

  # use bin/casseo as an executable template
  skeleton = File.read("./bin/casseo")
  source = source_files.map { |f| File.read(f) }.join("\n")
  source = skeleton.gsub(
    /# @@STANDALONE_START@@.*# @@STANDALONE_END@@\n\n/m, source)

  target = "./casseo"
  File.open(target, 'w') do |f|
    f.puts source
    f.chmod 0755
  end
  puts "Saved to #{target}"
end
