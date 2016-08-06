require_relative 'gen.rb'
require 'fileutils'

class CPPCompiler
    GEN = FWI::Generator::CPP.new

    def populate_options o
        @options = {
            :hpp => ".", :cpp => ".",
            :hpp_ext => ".hpp", :cpp_ext => ".cpp",
            :hpp_only => false
        };
        o.on("--headers [DIRECTORY]", "Directory to put Generated C++ Header Files.") { |x| @options[:hpp] = x }
        o.on("--sources [DIRECTORY]", "Directory to put Generated C++ Source Files.") { |x| @options[:cpp] = x }
        o.separator ""
        o.on("--header_ext [EXTENSION]", "Extension for Generated C++ Header Files. Default .hpp") { |x| @options[:hpp_ext] = x }
        o.on("--source_ext [EXTENSION]", "Extension for Generated C++ Source Files. Default .cpp") { |x| @options[:cpp_ext] = x }
        o.separator ""
        o.on("--header-only", "Compile as header-only") { |x| @options[:hpp_only] = true }
    end

    def after_parse; end
    def on_selected; end

    def compile file, lex, bitmap, options
        base = File.basename(file, File.extname(file))

        hpp_ext = @options[:hpp_ext]
        cpp_ext = @options[:cpp_ext]

        compile_cpp = !@options[:hpp_only]

        hpp = GEN.gen_hpp bitmap, hpp_ext, @options[:hpp_only]
        hpp.each do |fn, contents|
            f = File.join(@options[:hpp], fn)
            FileUtils.mkdir_p File.expand_path("..", f)
            File.write(f, contents)
        end

        if compile_cpp
            cpp = GEN.gen_cpp bitmap, cpp_ext, hpp_ext
            cpp.each do |fn, contents|
                f = File.join(@options[:cpp], fn)
                FileUtils.mkdir_p File.expand_path("..", f)
                File.write(f, contents)
            end
        end
    end

end