require_relative 'gen.rb'
require 'fileutils'

class JSCompiler
    GEN = FWI::Generator::JS.new

    def populate_options o
        @options = {}
        o.on("--bundle [NAME]", "Create a JavaScript bundle file with the given name") { |name| @options[:bundle] = name }
    end

    def after_parse; end
    def on_selected; end

    def compile file, lex, bitmap, options
        base = File.basename(file, File.extname(file))

        files = GEN.gen bitmap
        if @options[:bundle].nil?
            files.each do |fn, contents|
                f = File.join(options[:output], fn)
                FileUtils.mkdir_p File.expand_path("..", f)
                File.write(f, contents)
            end
        else
            contents = ""
            files.each do |fn, fcontents|
                contents << "// File: #{fn}\n"
                contents << fcontents
                contents << "\n"
            end
            f = File.join(options[:output], @options[:bundle])
            FileUtils.mkdir_p File.expand_path("..", f)
            File.write(f, contents)
        end
    end

end