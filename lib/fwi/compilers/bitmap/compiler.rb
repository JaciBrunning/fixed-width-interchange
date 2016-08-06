require 'fileutils'
require 'json'

class BitmapCompiler

    def populate_options o
    end

    def after_parse; end
    def on_selected; end

    def compile file, lex, bitmap, options
        base = File.basename(file, File.extname(file))
        f = File.join(options[:output], base + ".bitmap")
        FileUtils.mkdir_p File.expand_path("..", f)
        File.write(f, JSON.generate(bitmap))
    end

end