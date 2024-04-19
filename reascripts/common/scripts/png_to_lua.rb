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

  f.write("  pixels = {\n")
  (0...image.height).each do |y|
    row = '{'
    x = 0
    while x < image.width do
      length = 1
      rgba = ChunkyPNG::Color.to_truecolor_alpha_bytes(image[x, y])
      while x + length < image.width do
        if rgba == ChunkyPNG::Color.to_truecolor_alpha_bytes(image[x + length, y]) then
          length += 1
        else
          break
        end
      end
      row << "#{length},#{rgba[0]},#{rgba[1]},#{rgba[2]},#{rgba[3]},"
      x += length
    end
    row << '}'
    f.write("    #{row},\n")
  end
  f.write("  },\n")

  f.write("  bytes = table.concat({\n")
  image.to_blob.bytes.each_slice(100) do |slice|
    f.write("string.char(#{slice.join(",")}),\n")
  end
  f.write("  })\n")

  f.write("}\n")
end
