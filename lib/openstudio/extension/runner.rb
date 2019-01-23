module OpenStudio
  module Extension
    class Runner

      def initialize(path)
        # does the actions for the rake task
        puts "Initializing runner with path: #{path}"
        @path = path
      end

      # test measures of calling gem with OpenStudio CLI system call
      def test_measures_with_cli
        puts "Testing measures with CLI system call"
        measures_dir = @path + '/lib/measures'
        puts "measures path: #{measures_dir}"
        gem_path = `gem environment gempath`
        gem_path = gem_path.split(':')[0]
        gem_path = gem_path + '/gems'
        puts "GEM PATH: #{gem_path}"


        Dir.chdir(File.join(File.dirname(__FILE__), 'bundle'))
        rm_if_exist('Gemfile.lock')
        rm_if_exist('./test_gems')
        rm_if_exist('./bundle')

        system 'bundle install --path ./test_gems'
        system 'bundle lock --add_platform ruby'

        the_call = "openstudio --verbose --bundle Gemfile --bundle_path .test_gems/ measure -r #{measures_dir}"
        puts "SYSTEM CALL:"
        puts the_call
        system "#{the_call}"
        puts "DONE"
      end
    end
  end
end