require 'bundler'
require 'open3'
require 'openstudio'
require 'yaml'

module OpenStudio
  module Extension
    ##
    # The Runner class provides functionality to run various commands including calls to the OpenStudio CLI.  
    #
    class Runner

      ##
      # When initialized with a directory containing a Gemfile, the Runner will attempt to create a bundle 
      # compatible with the OpenStudio CLI.
      ##
      #  @param [String] dirname Directory to run commands in, defaults to Dir.pwd. If directory includes a Gemfile then create a local bundle.
      def initialize(dirname = Dir.pwd)
        puts "Initializing runner with dirname: '#{dirname}'"
        @dirname = File.absolute_path(dirname)
        @gemfile_path = File.join(@dirname, 'Gemfile')
        @bundle_install_path = File.join(@dirname, '.bundle/install/')
        
        raise "#{@dirname} does not exist" if !File.exists?(@dirname)
        raise "#{@dirname} is not a directory" if !File.directory?(@dirname)
        
        if !File.exists?(@gemfile_path)
          # if there is no gemfile set these to nil
          @gemfile_path = nil
          @bundle_install_path = nil
        else
          # there is a gemfile, attempt to create a bundle
          original_dir = Dir.pwd
          begin
            # go to the directory with the gemfile
            Dir.chdir(@dirname)
            
            # test to see if bundle is installed
            check_bundle = run_command('bundle -v', get_clean_env())
            if !check_bundle
              raise "Failed to run command 'bundle -v', check that bundle is installed" if !File.exists?(@dirname)
            end
            
            # TODO: check that ruby version is correct

            # check existing config
            needs_config = true
            if File.exists?('./.bundle/config')
              puts "config exists"
              config = YAML.load_file('./.bundle/config')
              if config['BUNDLE_PATH'] == @bundle_install_path
                # already been configured, might not be up to date
                needs_config = false
              end
            end
            
            # check existing platform
            needs_platform = true
            if File.exists?('Gemfile.lock')
              puts "Gemfile.lock exists"
              gemfile_lock = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock'))
              if gemfile_lock.platforms.include?('ruby')
                # already been configured, might not be up to date
                needs_platform = false
              end
            end          
            
            puts "needs_config = #{needs_config}"
            if needs_config
              run_command("bundle config --local --path '#{@bundle_install_path}'", get_clean_env())
            end
            
            puts "needs_platform = #{needs_platform}"
            if needs_platform
              run_command('bundle lock --add_platform ruby', get_clean_env())
              run_command('bundle update', get_clean_env())
            end
            
          ensure
            Dir.chdir(original_dir)
          end
        end
        
      end
      
      ##
      # Returns a hash of environment variables that can be merged with the current environment to prevent automatic bundle activation.
      #
      # DLM: should this be a module or class method?
      ##
      #  @return [Hash] 
      def get_clean_env()
        # blank out bundler and gem path modifications, will be re-setup by new call
        new_env = {}
        new_env["BUNDLER_ORIG_MANPATH"] = nil
        new_env["BUNDLER_ORIG_PATH"] = nil
        new_env["BUNDLER_VERSION"] = nil
        new_env["BUNDLE_BIN_PATH"] = nil
        new_env["RUBYLIB"] = nil
        new_env["RUBYOPT"] = nil
        
        # DLM: preserve GEM_HOME and GEM_PATH set by current bundle because we are not supporting bundle
        # requires to ruby gems will work, will fail if we require a native gem
        #new_env["GEM_PATH"] = nil
        #new_env["GEM_HOME"] = nil
        
        # DLM: for now, ignore current bundle in case it has binary dependencies in it
        #bundle_gemfile = ENV['BUNDLE_GEMFILE']
        #bundle_path = ENV['BUNDLE_PATH']    
        #if bundle_gemfile.nil? || bundle_path.nil?
          new_env['BUNDLE_GEMFILE'] = nil
          new_env['BUNDLE_PATH'] = nil
        #else
        #  new_env['BUNDLE_GEMFILE'] = bundle_gemfile
        #  new_env['BUNDLE_PATH'] = bundle_path    
        #end  
        
        return new_env
      end
      
      ##
      # Run a command after merging the current environment with env.  Command is run in @dirnamem, returns to Dir.pwd after completion.  
      # Returns true if the command completes successfully, false otherwise.
      # Standard Out, Standard Error, and Status Code are collected and printed, but not returned.
      ##
      #  @return [Boolean] 
      def run_command(command, env = {})
        result = false
        original_dir = Dir.pwd
        begin
          Dir.chdir(@dirname)
          stdout_str, stderr_str, status = Open3.capture3(env, command)
          if status.success?
            #puts "Command completed successfully"
            #puts "stdout: #{stdout_str}"
            #puts "stderr: #{stderr_str}"
            #STDOUT.flush
            result = true
          else
            puts "Error running command: '#{command}'"
            puts "stdout: #{stdout_str}"
            puts "stderr: #{stderr_str}"
            STDOUT.flush
            result = false 
          end
        ensure
          Dir.chdir(original_dir)
        end
        
        return result
      end

      ##
      # Run the OpenStudio CLI command to test measures on given directory
      # Returns true if the command completes successfully, false otherwise.
      ##
      #  @return [Boolean] 
      def test_measures_with_cli
        puts "Testing measures with CLI system call"
        measures_dir = File.join(@dirname, 'lib/measures/') # DLM: measures_dir should be a method of the extension mixin?
        puts "measures path: #{measures_dir}"

        cli = OpenStudio.getOpenStudioCLI
        puts "CLI: #{cli}"

        the_call = ''
        if @gemfile_path
          the_call = "#{cli} --verbose --bundle #{@gemfile_path} --bundle_path #{@bundle_path} measure -r #{measures_dir}"
        else
          the_call = "#{cli} --verbose measure -r #{measures_dir}"
        end
        
        puts "SYSTEM CALL:"
        puts the_call
        STDOUT.flush
        result = run_command(the_call, get_clean_env())
        puts "DONE"
        STDOUT.flush
        
        return result
      end
    end
  end
end