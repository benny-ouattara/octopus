require "test/unit"

# CSC 253 - DVCS Projects 
# Updated Unit Test for Repos
# 10/28/2015

class Test_Repos < Test::Unit::TestCase

	# Create values that will be used 
	# later in the test

	# @init_path used for where the DVCS 
	# will be initialized
	# @repo_path is repos directory
	# For the tree structure of Snapshots, my implementation idea is to make one 
	# folder to represent one Snapshot, folder name will be the node_id of the 
	# snapshot. Childern of specific Snapshot will be another folder created in that
	# specific folder

	############################################################################


	def setup
		@Username = "CSC253"
		@init_path = "Desktop/DVCS/Test"
		@repo_path = "Desktop/DVCS/Test/.oct"


		
	end

	# Test the initialization of the repos
	# Input is @init_path created before
	def test_init()
		# make the directory to be the test area I want
		Dir.chdir(@init_path)
		
		# call init to create repos with the name ".oct"
		init()

		# make sure init() worked normally
		# create all files user needs
		assert_equal(true, File.directory?(@repo_path))
		assert_equal(@init_path, File.dirname(@repo_path))

	end


	# Test make_snapshot, record version ids of a list of files 
	# and the corresponding reference id to communicate with Revlog
	def test_make_snapshot():
		# Call make_snapshot() function, it will always take stage in workspace as parameter
		# Create version id for each file and file id in order to communicate with Revlog
		# Created a new file to workspace and add
		Dir.chdir(@init_path)
		File.open("test1.txt", 'w'){|f| f.puts("First line")}
		# Call function in workspace module
		stage("test1.txt")
		# Then call make_snapshot
		@node_id1 = make_snapshot()
		# Created a Snapshot with name node_id1
		assert_equal(true, File.exist?(@repo_path + "/" + @node_id1))

		# Modify test1.txt and create another snapshot
		File.open("test1.txt", 'w'){|f| f.puts("Second line")}
		@node_id11 = make_snapshot()
		# Will be in the sub-folder of first Snapshot
		assert_equal(true, File.exist?(@repo_path + "/" + @node_id1 + "/" + @node_id11))


	end

	# Test restore_snapshot, which takes a node_id that represents a Snapshot
	# and return list of file_id's 
	# 
	def test_restore_snapshot():
		# Try to restore the first snapshot, only have one file
		@file_id = restore_snapshot(@node_id1)
		# call Revlog to verify if it's the first snapshot's 
		assert_equal(get_file(@file_id), "First line")

	end


	# Test history, which takes a specific Snapshot's node_id and return all
	# parent of this node, which are all histories.
	def test_history():
		# Find history of the latest node_id
		@node_ids = history(@node_id11)
		# Only have one history, which is the first snapshot
		assert_equal(@node_ids = [node_id1])

	end

	# Test make_branch, which takes a specific node_id and make_branch make a new Snapshot
	# from that Snapshot
	def test_make_branch():
		# After call make_branch on second Snapshot, we will see two folders in node_id1
		@node_id12 = make_branch(@node_id11)
		# go to node_id1 folder
		Dir.chdir(@repo_path + "/" + "node_id1")
		# Find folder names and save into an array, which will equal to two branches' node ids
		@folders_name_array = Dir.glob('*').select{|f| File.directory? f}
		assert_equal(@folders_name_array, ["node_id11", "node_id12"])

	end

	# Test delete_branch, which takes a specific node_id and delete this Snapshot
	def test_delete_branch():
		# Delete the branch of node_id11
		delete_branch(@node_id12)
		# Find folder name again, now we only have node_id11
		@folders_name_array = Dir.glob('*').select{|f| File.directory? f}
		assert_equal(@folders_name_array, ["node_id11"])


	end

	# Test diff_snapshots, which takes two different snapshots and return list of file
	# changes by calling Revlog
	def test_diff_snapshots():
		# This function will call Revlog using file_id
		@diff_contents = diff_snapshots(node_id1, node_id11)
		assert_equal(@diff_contents, "Second line")


	end

	# Test merge, which takes two different node_id and call Revlog and return a new Snapshot
	def test_merge():
		# Re-create the branch of node_id11 and add a new line to test1.txt
		@node_id12 = make_branch(@node_id11)
		Dir.chdir(@repo_path + "/" + @node_id1 + "/" + @node_id12))
		File.open("test1.txt", 'w'){|f| f.puts("Third line")}
		
		# Merge node_id11, node_id12
		@node_id_merged = merge(@node_id11, @node_id12)
		@diff_contents = diff_snapshots(node_id_merged, @node_id11)
		assert_equal(@diff_contents, "Third line")
		

	end

end
