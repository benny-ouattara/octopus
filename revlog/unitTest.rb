require_relative 'revlog'
require 'test/unit'


class Tests < Test::Unit::TestCase

	###########
	# Setup   #
	###########
	def setup
		@test_file1 = File.new('test1.txt', 'w') #create a test file
		@test_file1.puts("first\nfile\nanarchy\n")
		@test_file1.close
		@test_file1 = 'test1.txt'

		@test_file2 = File.new('test2.txt', 'w') #create a second test file
		@test_file2.puts("second\nfile\nNaNarchy\n")
		@test_file2.close
		@test_file2 = 'test2.txt'
	end

	###########
	# Cleanup #
	###########
	def teardown
		# Destroy test files
		ObjectSpace.each_object(File) {|f| f.close unless f.closed?} #close loose files
		File.delete('test1.txt','test2.txt')
	end



	#########################################################
	# Tests													#
	#########################################################

	############
	# add_file #
	############
	def test_add_file

		#stores two files
		#fails if the hash ids
		#returned are invalid
		#or the same

		id1 = Revlog.add_file(File.open(@test_file1).read) #call add_file
		id2 = Revlog.add_file(File.open(@test_file2).read) #call add_file
		assert_not_equal(id1,id2,"ID's were equal (we broke SHA2)")

	end
	#########################################################
	# end add_file											#
	#########################################################


	############
	# get_file #
	############
	def test_get_file
		id1 = Revlog.add_file(File.open(@test_file1).read) #call add_file
		id2 = Revlog.add_file(File.open(@test_file2).read) #call add_file

		#loads the two files previously stored
		#fails if retrieved files are not original files

		assert_equal(File.open(@test_file1).read, Revlog.get_file(id1), "Unexpected file loaded (file 1)")
		assert_equal(File.open(@test_file2).read, Revlog.get_file(id2), "Unexpected file loaded (file 2)")
	end
	#########################################################
	# end get_file 											#
	#########################################################



	###############
	# delete_file #
	###############
	def test_delete_file
		id1 = Revlog.add_file(File.open(@test_file1).read) #call add_file
		id2 = Revlog.add_file(File.open(@test_file2).read) #call add_file

		#deletes the file previously stored
		#fails if deletion exits unsuccessfully
		#or if the file can be retrieved afterwards

		assert_equal(0, Revlog.delete_file(id1), "File deletion unsuccessful")
		assert_raise(RuntimeError, "File not properly deleted") {Revlog.get_file(id1)}
		
	end
	#########################################################
	# end delete_file 										#
	#########################################################



	##############
	# diff_files #
	##############
	def test_diff_files

		#diff_files(fileA, fileB): returns a list of differences between the two files

		#tests to make sure a file diffed with
		#itself is unchanged, and that file diffs
		#involving partial/entire content work properly

		merge_file1 = File.new("merger1.txt", 'w+') #create a test file
		merge_file1.puts("file\nanarchy\nNaNarchy")
		merge_file1.rewind

		merge_file2 = File.new("merger2.txt", 'w+') #create a test file
		merge_file2.puts("or else")
		merge_file2.rewind

		file1 = Revlog.add_file(File.open(@test_file1).read)
		mfile1 = Revlog.add_file(merge_file1.read)
		mfile2 = Revlog.add_file(merge_file2.read)

		assert_equal([], Revlog.diff_files(file1, file1),  "Self comparison faiure")

		assert_equal(["first\n","NaNarchy\n"], Revlog.diff_files(file1, mfile1), "Diff failure 1")

		assert_equal(["first\n","file\n","anarchy\n", "or else\n"], Revlog.diff_files(file1, mfile2), "Diff failure 2")

		#Cleanup
		merge_file1.close
		merge_file2.close
		File.delete("merger1.txt", "merger2.txt")

	end
	#########################################################
	# end diff_files 										#
	#########################################################



	#########
	# merge #
	#########
	def test_merge

		#merge(fileA, fileB, ancest_file = nil): returns a merged file or conflict file plus a new file id

		#tests to make sure a file merged with
		#itself is unchanged, and that simple
		#and complex file merges work properly
		#also does one fully intensive case

		ancestor_file = File.new('ancest1.txt', 'w+') #create a test file
		ancestor_file.puts("file\n")
		ancestor_file.rewind

		merge_file1 = File.new('merger1.txt', 'w+') #create a test file
		merge_file1.puts("file\nanarchy\nNaNarchy")
		merge_file1.rewind

		merge_file2 = File.new('merger2.txt', 'w+') #create a test file
		merge_file2.puts("first\nfile\nanarchy\nNaNarchy")
		merge_file2.rewind

		merged = File.new('merged.txt', 'w+') #create a test file
		merged.puts("<<<<<<<< ours\nfirst\n========\nsecond\n>>>>>>>> theirs\n")
		merged.puts("file\n<<<<<<<< ours\nanarchy\n========\nNaNarchy\n>>>>>>>> theirs\n")
		merged.rewind

		file1 = Revlog.add_file(File.open(@test_file1).read)
		file2 = Revlog.add_file(File.open(@test_file2).read)
		ancest = Revlog.add_file(ancestor_file.read)
		mfile1 = Revlog.add_file(merge_file1.read)
		mfile2 = Revlog.add_file(merge_file2.read)
		merge = Revlog.add_file(merged.read)

		revlog_merged = Revlog.add_file(File.open('revlog_merged.rb').read)
		revlog_old = Revlog.add_file(File.open('revlog_old.rb').read)
		revlog_new = Revlog.add_file(File.open('revlog_new.rb').read)

		assert_equal(Revlog.get_file(file1), Revlog.get_file(Revlog.merge(file1, file1)), "Self comparison failure (no ancestor)")
		# assert_equal(Revlog.get_file(file1), Revlog.get_file(Revlog.merge(file1, file1, ancest)), "Self comparison failure (ancestor)")

		assert_equal(Revlog.get_file(mfile2), Revlog.get_file(Revlog.merge(file1, mfile1)), "Simple merge failure (no ancestor)")
		# assert_equal(Revlog.get_file(mfile2), Revlog.get_file(Revlog.merge(file1, mfile1, ancest)), "Simple merge failure (ancestor)")

		assert_equal(Revlog.get_file(merge), Revlog.get_file(Revlog.merge(file1, file2)), "Complex merge failure (no ancestor)")
		# assert_equal(Revlog.get_file(merge), Revlog.get_file(Revlog.merge(file1, file2, ancest)), "Complex merge failure (ancestor)")

		assert_equal(Revlog.get_file(revlog_merged).force_encoding('UTF-8'), Revlog.get_file(Revlog.merge(revlog_old, revlog_new)), "Intensive merge failure (no ancestor)")
		# assert_equal(Revlog.get_file(revlog_merged), Revlog.get_file(Revlog.merge(revlog_old, revlog_new, revlog_ances)), "Intensive merge failure (ancestor)")

		#Cleanup
		ancestor_file.close
		merge_file1.close
		merge_file2.close
		merged.close
		File.delete('ancest1.txt', 'merger1.txt', 'merger2.txt', 'merged.txt')

	end
	#########################################################
	# end merge 											#
	#########################################################
end