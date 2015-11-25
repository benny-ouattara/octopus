require_relative "#{File.dirname(__FILE__)}/../repo/repos"
require_relative "#{File.dirname(__FILE__)}/../workspace/workspace"
require 'io/console'
require 'fileutils'
require 'tempfile'
require 'net/ssh'
require 'json'
require 'etc'
require 'shellwords'

module PushPull

  @@dvcs_dir = '.octopus' # Name of the directory containing the DVCS files
  @@repo_dir = ".octopus/repo"
  @@revlog_dir = ".octopus/revlog"

  # private_class_method :pull_with_connection

  # Uses the Net::SSH gem to create an SSH session.
  # The user will be asked for their credentials for the connection,
  # unless they have a key configured for the connection.
  #
  # @param [string] remote The address of the remote machine to connect to.
  # @param [string] path The path to the corresponding repo on the remote.
  # @yield [ssh] Custom block for utilizing the connection.
  # @yieldparam [Net::SSH] ssh The ssh connection object.
  #
  def self.connect(remote, path)
    name_machine, folder = remote.split(":")
    user, machine = name_machine.split("@")
    begin
      # Attempt to login as the current user with a key
      ssh = Net::SSH.start(machine, user)
    rescue
      begin
        print 'Username: '
        username = STDIN.gets.chomp           # Remove trailing newline
        print 'Password: '
        password = STDIN.noecho(&:gets).chomp # Remove trailing newline
      
        ssh = Net::SSH.start(remote, username, :password => password)
      rescue
        return 'Unable to connect to remote'
      end
    end

    if block_given?
      yield ssh
    end

    ssh.close
  end

  # Pushes new changes from the local repo to a remote repo.
  # An exception is raised if the user needs to pull before they can push.
  #
  # @param [string] remote The address of the remote machine to connect to.
  #                        For example: 127.0.0.1:/path/to/repo
  # @param [string] branch The name of the branch to push to.
  # 
  def self.push(remote, branch)
    # Splits 127.0.0.1:/path/to/repo into 127.0.0.1 and /path/to/repo
    address, path = remote.split(':', 2)

    self.connect(address, path) { |ssh|
      # This was not working
      # remote_head = ssh.exec! "oct get_head #{branch}"

      # Collect the branch file
      @branch_file = (ssh.exec! "cat #{path}/#{@@dvcs_dir}/repo/branches")
      branch_table = Marshal.load(@branch_file)
      remote_head = branch_table[branch]
      # puts "from push"
      # puts remote_head

      Repos.get_latest_snapshots(remote_head)
      marshal_local = File.read('.octopus/communication/text_file').to_s

      # Raise an exception if local changes could not be calculated
      return 'Local is not up to date, please pull and try again' if !marshal_local

      # Copy the contents of the local file to remote/#{@@dvcs_dir}/communication/text_file
      ssh.exec "echo #{marshal_local} > #{@@dvcs_dir}/communication/text_file"

      # Merge the new snapshots into the remote
      ssh.exec "oct update #{@@dvcs_dir}/communication/text_file"

      # This is not working... when you ssh into the remote, you do not get to the right directory and
      # so all the ssh.exec are failing.

      # where_are_we = ssh.exec "pwd"
      # puts where_are_we

      # Updating remote workspace directory
      ssh.exec "oct checkout #{branch}"
    }
  end

  # Pulls new changes from the remote repo to the local repo.
  # An exception is raised if the remote does not have the local HEAD in its history
  #
  # @param [string] remote The address of the remote machine to connect to.
  #                        For example: 127.0.0.1:/path/to/repo
  # @param [string] branch The name of the branch to pull.
  # 
  def self.pull(remote, branch)
    # Splits 127.0.0.1:/path/to/repo into 127.0.0.1 and /path/to/repo
    address, path = remote.split(':', 2)

    self.connect(address, path) { |ssh|
      pull_with_connection(branch, ssh)
    }
  end

  # Pulls new changes from the remote repo to the local repo.
  # An exception is raised if the remote does not have the local HEAD in its history,
  # or if the given branch does not exist locally or on the remote.
  #
  # This method should be considered private.
  #
  # @param [string] branch The name of the branch to pull.
  # @param [Net::SSH] ssh The ssh connection object to use.
  #
  def self.pull_with_connection(branch, ssh)
    local_head = Repos.get_head(branch)

    # Calling either of these `oct func` methods updates
    # the #{@@dvcs_dir}/communication/text_file file on the remote
    if local_head.nil?
      # Get the entire history if our locally history is empty
      if ssh.exec! "oct get_all_snapshots" == 'error'
        raise 'Remote has no commit history'
      end
    else
      # Get the history since our latest local snapshot
      if ssh.exec! "oct get_latest_snapshot #{local_head}" == 'error'
        raise 'Local commit history is not present on remote'
      end
    end

    # Merge the new remote snapshots into the local repo
    TempFile.open('snapshots_to_merge') { |file|
      # Copy over the file contents from the remote
      file.write(ssh.exec! "cat #{@@dvcs_dir}/communication/text_file")

      # Update our local snapshot tree
      Repos.update_tree(file.path)
    }
  end

  # Clones all branches from the given remote repository to a local directory.
  # An exception is raised if the destination directory already exists
  #
  # @param [string] remote The address of the remote machine to clone.
  # @param [string] directory_name The name of the directory to clone the repo into.
  #                                Defaults to the name of the repository on the remote.
  #
  def self.clone(remote, directory_name = nil)
    # The directory name is the name of the repository by default
    directory_name = directory_name.nil? ? File.basename(remote) : directory_name

    # Ensure the directory does not already exist
    return 'Destination for clone already exists' if Dir.exists?(directory_name)

    Dir.mkdir(directory_name)

    # Initialize the new repository
    Dir.chdir(directory_name) {
      workspace = Workspace.new
      workspace.init

      # Splits 127.0.0.1:/path/to/repo into 127.0.0.1 and /path/to/repo
      address, path = remote.split(':', 2)
      self.connect(address, path) { |ssh|
        # Obtain a list of branches on the remote
        # TODO I need a real way to get all branch names
        @head_file = (ssh.exec! "cat #{path}/#{@@dvcs_dir}/repo/head")
        @store_file = (ssh.exec! "cat #{path}/#{@@dvcs_dir}/repo/store")
        @revlog_file = (ssh.exec! "cat #{path}/#{@@dvcs_dir}/revlog/revlog.json")
        @branch_file = (ssh.exec! "cat #{path}/#{@@dvcs_dir}/repo/branches")

        # # Always include the master branch
        # branches.push('master') unless branches.include?('master')

        # # Pull each branch
        # branches.each { |branch|
        #   self.pull_with_connection(branch, ssh)
        # }
      }

      File.open("#{@@repo_dir}/head", 'wb'){|f| f.write(@head_file)}
      File.open("#{@@repo_dir}/store", 'wb'){|f| f.write(@store_file)}
      File.open("#{@@repo_dir}/branches", 'wb'){|f| f.write(@branch_file)}
      File.open("#{@@revlog_dir}/revlog.json", 'wb'){|f| f.write(@revlog_file)}
      workspace.check_out_branch("master")
    }
    return "You have succesfully cloned from #{remote}"
  end
end
