require 'fwi/compilers/cpp/compiler.rb'
require 'fwi/compilers/js/compiler.rb'
# require_relative 'js/compiler.rb'

require_relative 'parser.rb'
require 'optparse'

COMPILERS = {
    "cpp" => CPPCompiler.new,
    "js" => JSCompiler.new
};

options = {
    :source_root => ".", :output => "."
}
optp = OptionParser.new do |opts|
    
    opts.separator ""
    opts.separator "Common options:"

    opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
    end

    opts.on("-l", "--language LANGUAGE", COMPILERS.map { |n, v| n }, 
        "Select the language to compile down to. One of [#{COMPILERS.keys.join(", ")}]") do |lang|
        options[:language] = lang
    end

    opts.on("-d", "--source-dir [DIRECTORY]", "Set the source directory to pull files from") do |directory|
        options[:source_root] = directory
    end

    opts.on("-o", "--output [DIRECTORY]", "Directory to put Generated Files") { |x| options[:output] = x }

    COMPILERS.each do |n,x|
        opts.separator ""
        opts.separator n 
        x.populate_options opts 
    end

   
end

begin
  optp.parse!
  mandatory = [:language]                                
  missing = mandatory.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s 
  puts optp
  exit
end   

source_files = ARGV
COMPILERS.each { |n,x| x.after_parse }
selected_compiler = COMPILERS[options[:language]]

p = FWI::Parser.new

selected_compiler.on_selected
source_files.each do |file|
    lex = p.lex(file, options[:source_root])
    bitmap = p.bitmap(lex)
    selected_compiler.compile file, lex, bitmap, options
end
