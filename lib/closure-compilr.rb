require 'open-uri'
require 'tempfile'

module ClosureCompilr # :nodoc:
  
  #   JSCompilation.new('myjsfile.js').compile #=> /user/me/projects/myproject/public/javascripts/myjsfile.min.js
  class JSCompilation
    
    COMPILER_FILE_LOCATION = File.join File.dirname(__FILE__),'..','bin',"closure-compiler.jar"
    COMPILER_VERSION = 20091217
    
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
    attr_accessor :file,:filename,:other_files,:write_path, :compiler_version
    
    
    # ==== Params
    # - fname:      Filename of javascript file to compile
    # - opts:       Options to pass
    def initialize(fname,opts={})
      @root = opts.fetch(:root,@@root)
      @tempfiles = Array.new
      @filename = fname
      @compiler_version = opts.fetch(:compiler_version,COMPILER_VERSION)
      if m = @filename.match(/(.+[\\|\/])(.+)/)
        @filename = m[2]
        @js_path = File.join( m[1].split(/[\\|\/]+/) )
        @write_path = opts.fetch(:write_path,File.join(@root,@js_path) )
      else
        @js_path = opts.fetch(:root,@@js_path)
        @write_path = opts.fetch(:write_path,@@write_path)
      end
      # @file = File.new(filename)
      
      process_opts
    end
    
    def process_opts # :nodoc:
      start_reading = nil
      @other_files = File.open(file_path).inject([]) do |result,line|
        
        unless start_reading
          start_reading = line =~ /==ClosureCompiler==/
          next result
        end
        break result if line =~ /==\/ClosureCompiler==/
        
        if m=line.match(/@code_path (.+)/i)
          path = File.join @@root,@@js_path,File.join( m[1].split(/[\\|\/]+/) )
          begin
            File.open(path)
          rescue Errno::ENOENT
            raise JSCompInvalidFile, "File cannot be found: #{path}"
          end
          result << path
        elsif m=line.match(/@code_url (.+)/i)
          url = m[1]
          filename = url.match(/.+\/(.+)/)
          if filename
            filename = filename[1]
          else
            next result
          end
          temp = Tempfile.new(filename)
          temp.write open(url).read
          temp.flush
          @tempfiles << temp
          result << temp.path
        elsif m=line.match(/@compilation_level (.+)/i)
          @compilation_level = m[1]
        elsif m=line.match(/@formatting (.+)/i)
          @formatting = m[1]
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
    
    def compiler_file_location # :nodoc:
      @compiler_version ? File.join(File.dirname(__FILE__),'..','bin',"closure-compiler-#{@compiler_version}.jar") : COMPILER_FILE_LOCATION
    end
    
    # Compile's the javascript file and all dependencies
    def compile
      cmd = "java -jar #{compiler_file_location}"
      cmd << " --compilation_level #{@compilation_level}" if @compilation_level
      cmd << " --formatting #{@formatting}" if @formatting
      all_files.each do |file|
        cmd << " --js #{file}"
      end
      cmd << " --js_output_file #{output_path}"
      
      output = `#{cmd}`
      
      output_path
    end
    alias compress compile
    
    # Closes out the tempfiles generated by downloading external javascripts
    def close_tempfiles
      @tempfiles.each {|f| f.close}
    end
  end

  # Error type returned if there was an error compiling
  class JSCompilationFailed < StandardError; end
  # Error type returned if one of hte dependencies listed wasn't found
  class JSCompInvalidFile < JSCompilationFailed; end
end

include ClosureCompilr