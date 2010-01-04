module ClosureCompilr
  VERSION = "0.0.1"
  VERSION_HASH = {:major => 0, :minor => 0, :patch => 1}
  COMPILER_FILE_LOCATION = File.join File.dirname(__FILE__),'..','bin',"closure-compiler.jar"
  COMPILER_VERSION = 20091217
  
  
  # YAY THIS WORKS!!!
  class JSCompilation
    class << self
      def root;@@root;end
      def root=r;@@root=r;end
      def js_path;@@js_path;end
      def js_path=j;@@js_path=j;end
      def write_path;@@write_path;end
      def write_path=w;@@write_path=w;end
    end
    if defined? Merb
      @@root,@@js_path = Merb.root_path, File.join('public','javascripts')
      @@write_path = File.join(@@root,@@js_path)
    elsif defined? RAILS_ROOT
      @@root,@@js_path = RAILS_ROOT, File.join('public','javascripts')
      @@write_path = File.join(@@root,@@js_path)
    end
    attr_accessor :file,:filename,:other_files,:write_path

    def initialize(fname,opts={})
      @root = opts.fetch(:root,@@root)

      @filename = fname
      if m = @filename.match(/(.+[\\|\/])(.+)/)
        @filename = m[2]
        @js_path = File.join( m[1].split(/[\\|\/]+/) )
        @write_path = opts.fetch(:write_path,File.join(@root,@js_path) )
      else
        @js_path = opts.fetch(:root,@@js_path)
        @write_path = opts.fetch(:write_path,@@write_path)
      end
      # @file = File.new(filename)

      @other_files = File.open(file_path).inject([]) do |result,line|
        if m=line.match(/@code_path (.+)/i)
          path = File.join @@root,@@js_path,File.join( m[1].split(/[\\|\/]+/) )
          begin
            File.open(path)
          rescue Errno::ENOENT
            raise JSCompInvalidFile, "File cannot be found: #{path}"
          end
          result << path
        end
        result
      end

    end

    def file_path
      File.join(@@root,@@js_path,filename)
    end

    # All the files to be processed together
    def all_files
      other_files + file_path.to_a
    end

    # Filename of the file to be output
    def output_filename
      filename.gsub(/\.js$/i,'.min.js')
    end

    # Full path of the file to be output
    def output_path
      File.join @write_path, output_filename
    end

    def compile
      output = `java -jar closure-compiler.jar -js #{all_files.join(' ')} --js_output_file #{output_path}.test`
    end
  end

  # Error type returned if there was an error compiling
  class JSCompilationFailed < StandardError; end
  class JSCompInvalidFile < JSCompilationFailed; end
end