require 'yaml'
require 'pathname'
require 'filewatcher'

module OpenshiftReliability
  class Config

    attr_reader  :home,:tasks,:keys,:masters,:master,:port,:nodes,:etcds,:routers,:gituser,:authtype,:htpasswd,:templates,:prefix,:projectload,:tasknum
    def initialize(config:nil)
      filewatcher = FileWatcher.new([Pathname.new(File.dirname(__FILE__)).realpath.to_s+"/../config/config.yaml"])
      thread = Thread.new(filewatcher){
        |fw| fw.watch{
          |f| puts "Reloading configs : " + f
          load_config()
        }
      }

      load_config()
      @taskfile=@home+"/runtime/tasknum"
      @seqnum=1
      @tasknum=1
      if File.file?(@taskfile); then
        file=File.open(@taskfile, "r")
        @tasknum=file.readline.to_i
      else
        file=File.new(@taskfile, "w+")
        file.puts(1)
      end
      file.close
    end

    def load_config()
      puts "Inside load_config"
      @home=Pathname.new(File.dirname(__FILE__)).realpath.to_s+"/../"
      @config=@home+"config/config.yaml"
      @tasks=@home+"config/tasks/"
      @keys=@home+"runtime/keys/"
      @configs = YAML.load_file(@config)
      @masters=@configs["environment"]["masters"]
      @master = @masters.first
      @nodes=@configs["environment"]["nodes"]
      @etcds=@configs["environment"]["etcds"]
      @routers= @configs["environment"]["routers"]
      @authtype= @configs["environment"]["authtype"]
      @port= @configs["environment"]["port"]
      @htpasswd= @configs["environment"]["htpasswd"]
      @gituser= @configs["exection"]["gituser"]
      @templates=@configs["exection"]["templates"]
      @projectload=@configs["exection"]["projectload"]
      @prefix= @configs["exection"]["userprefix"]
    end

    def save()
      file=File.open(@taskfile, "w+")
      file.puts(@tasknum)
      file.close
    end
    
    def increment_tasknum()
      @tasknum=@tasknum+1
    end

    def schedule()
      return @configs["schedule"]
    end

    def seq()
      @seqnum = @seqnum + 1
      return "#{@tasknum}-#{@seqnum}"
    end
    
    def taskseq()
      @tasknum=@tasknum+1
      file=File.open(@taskfile, "w+")
      file.puts(@tasknum)
      file.close
      return @tasknum.to_s
    end
  end
end
