require_relative 'gen.rb'
require 'fileutils'

class JSCompiler
    GEN = FWI::Generator::JS.new

    def populate_options o
    end

    def after_parse; end
    def on_selected; end

    def compile file, lex, bitmap, options
        base = File.basename(file, File.extname(file))

        files = GEN.gen bitmap
        files.each do |fn, contents|
            f = File.join(options[:output], fn)
            FileUtils.mkdir_p File.expand_path("..", f)
            File.write(f, contents)
        end
    end

end