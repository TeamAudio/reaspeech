# png_to_lua.rb - Convert a PNG image to Lua source

require 'chunky_png'

if ARGV.length < 2
  puts "Usage: #{$0} <input.png> <output.lua>"
  exit 1
end

input_filename = ARGV[0]
output_filename = ARGV[1]

image = ChunkyPNG::Image.from_file(input_filename)
image_name = File.basename(input_filename, File.extname(input_filename))

File.open(output_filename, 'w') do |f|
  f.write("IMAGES = IMAGES or {}\n")
  f.write("IMAGES['#{image_name}'] = {\n")
  f.write("  width = #{image.width},\n")
  f.write("  height = #{image.height},\n")

  f.write("  bytes = table.concat({\n")
  image.to_blob.bytes.each_slice(100) do |slice|
    f.write("string.char(#{slice.join(",")}),\n")
  end
  f.write("  })\n")

  f.write("}\n")
end
