guard 'rspec', cmd: "rspec" do

  # watch /lib/ files
  watch(%r{^lib/(.+).rb$}) do |m|
    "spec/lib/#{m[1]}_spec.rb"
  end

# watch /spec/ files
  watch(%r{^spec/lib/(.+).rb$}) do |m|
    "spec/lib/#{m[1]}.rb"
  end
end
