task :standalone do
  skeleton = File.read("./bin/casseo")

  source_files = File.read("./lib/casseo.rb").
    scan(/require_relative "(.*)"/).map { |f| "./lib/#{f.first}.rb" }

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
