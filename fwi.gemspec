lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fwi"
  spec.version       = "1.2.4"
  spec.authors       = ["Jaci Brunning"]
  spec.email         = ["jaci.brunning@gmail.com"]

  spec.summary       = %q{Fixed-Width Data Interchange Compiler}
  spec.homepage      = "http://github.com/JacisNonsense/Fixed-Width-Interchange"

  spec.bindir        = "bin"
  spec.files = Dir.glob("lib/**/*") + ['fwi.gemspec', 'Gemfile', 'LICENSE']
  spec.executables   = ["fwi"]
  spec.require_paths = ["lib"]
end