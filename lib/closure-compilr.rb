module ClosureCompilr
  VERSION = "0.0.1"
  VERSION_HASH = {:major => 0, :minor => 0, :patch => 1}
  COMPILER_FILE_LOCATION = File.join File.dirname(__FILE__),'..','bin',"closure-compiler.jar"
  COMPILER_VERSION = 20091217
  
  
  #   JSCompilation.new('myjsfile.js').compile #=> /user/me/projects/myproject/public/javascripts/myjsfile.min.js
  class JSCompilation
    class << self 
      def root# :nodoc:
        @@root;
      end
      
      # Manually set the root path of the application you're using
      #   JSCompilation.root = '/user/me/projects/myproject'
      def root=(r);@@root=r;end
      
      def js_path# :nodoc:
        @@js_path
      end
      
      # Manually set the storage location for javascript files relative to the root path
      #   JSCompilation.js_path = 'public/javascripts'
      def js_path=(j);@@js_path=j;end
      
      def write_path# :nodoc:
        @@write_path
      end
      # The directory to output the completed file. Defaults to root path combined with js_path
      #   JSCompilation.write_path = '/user/me/projects/myproject/public/javascripts'
      def write_path=(w);@@write_path=w;end
    end
    if defined? Merb
      @@root,@@js_path = Merb.root_path, File.join('public','javascripts')
      @@write_path = File.join(@@root,@@js_path)
    elsif defined? RAILS_ROOT
      @@root,@@js_path = RAILS_ROOT, File.join('public','javascripts')
      @@write_path = File.join(@@root,@@js_path)
    end
    attr_accessor :file,:filename,:other_files,:write_path
    
    
    # ==== Params
    # - fname:      Filename of javascript file to compile
    # - opts:       Options to pass
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
    
    # Full path of the source file
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
    
    # Compile's the javascript file and all dependencies
    def compile
      output = `java -jar closure-compiler.jar -js #{all_files.join(' ')} --js_output_file #{output_path}`
      output_path
    end
    alias compress compile
  end

  # Error type returned if there was an error compiling
  class JSCompilationFailed < StandardError; end
  # Error type returned if one of hte dependencies listed wasn't found
  class JSCompInvalidFile < JSCompilationFailed; end
end