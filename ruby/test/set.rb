require 'rubygems'
require 'test/unit'
require 'mocha'
require 'defines'
require 'tinymud'
require 'pp'

module TinyMud
    class TestSet < Test::Unit::TestCase
		def setup
			@db = TinyMud::Db.new
		end

		def teardown
			@db.free()
		end
		
		def test_do_name
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			fish = @db.add_new_record
			record(place) {|r| r.merge!({ :name => "place", :description => "yellow", :succ=>"yippee", :fail => "shucks", :osucc => "ping", :ofail => "darn", :contents => bob, :flags => TYPE_ROOM }) }
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => fish ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			record(fish) {|r| r.merge!({ :name => "fish", :location => place, :description => "slimy", :flags => TYPE_THING, :owner => anne  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_name(bob, "doesn't exist", "become real")
			
			# Player must control the "thing" to name
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_name(bob, "fish", "chip")
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_name(bob, "here", "haddock")
			
			# Rename self!
			# Missing password
			Interface.expects(:do_notify).with(bob, "Give it what new name?").in_sequence(notify)
			set.do_name(bob, "bob", nil)
			# Empty password
			Interface.expects(:do_notify).with(bob, "You must specify a password to change a player name.").in_sequence(notify)
			Interface.expects(:do_notify).with(bob, "E.g.: name player = newname password").in_sequence(notify)
			set.do_name(bob, "bob", "mary ")
			# Incorrect password
			Interface.expects(:do_notify).with(bob, "Incorrect password.").in_sequence(notify)
			set.do_name(bob, "bob", "mary sprouts")
			# Not got enough money
			Interface.expects(:do_notify).with(bob, "You can't give a player that name.").in_sequence(notify)
			set.do_name(bob, "bob", "mary sprout")
			# Enough money, bad name
			record(bob) {|r| r[:pennies] = LOOKUP_COST}
			Interface.expects(:do_notify).with(bob, "You can't give a player that name.").in_sequence(notify) # Same as above!
			set.do_name(bob, "bob", "here sprout")
			assert_equal(0, @db.get(bob).pennies) # But it has taken your money - Bug!
			# All ok
			record(bob) {|r| r[:pennies] = LOOKUP_COST}
			Interface.expects(:do_notify).with(bob, "Name set.").in_sequence(notify)
			set.do_name(bob, "bob", "mary sprout")
			assert_equal("mary", @db.get(bob).name)
			
			# Rename a non-player (thing) you own (note code checks all the same so won't repeat)
			# Poor name
			Interface.expects(:do_notify).with(bob, "That is not a reasonable name.").in_sequence(notify)
			set.do_name(bob, "cheese", "me")
			# Ok
			Interface.expects(:do_notify).with(bob, "Name set.").in_sequence(notify)
			set.do_name(bob, "cheese", "pie")
			assert_equal("pie", @db.get(cheese).name)
		end
		
		# The next few tests could/should be common'd up (they only differ by field tested)
		def test_do_describe
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')

			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_describe(bob, "doesn't exist", "become real")
			
			# Can change description so long as you own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_describe(bob, "anne", "fred")
			
			# Something we own
			Interface.expects(:do_notify).with(bob, "Description set.").in_sequence(notify)
			set.do_describe(bob, "cheese", "best eaten early in the day")
			assert_equal("best eaten early in the day", @db.get(cheese).description)
		end
		
		def test_do_fail
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')

			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_fail(bob, "doesn't exist", "become real")
			
			# Can change description so long as you own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_fail(bob, "anne", "fred")
			
			# Something we own
			Interface.expects(:do_notify).with(bob, "Message set.").in_sequence(notify)
			set.do_fail(bob, "cheese", "you failed to eat the cheese")
			assert_equal("you failed to eat the cheese", @db.get(cheese).fail)
		end
		
		def test_do_success
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')

			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_success(bob, "doesn't exist", "become real")
			
			# Can change description so long as you own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_success(bob, "anne", "fred")
			
			# Something we own
			Interface.expects(:do_notify).with(bob, "Message set.").in_sequence(notify)
			set.do_success(bob, "cheese", "you eat the cheese")
			assert_equal("you eat the cheese", @db.get(cheese).succ)
		end
		
		def test_do_osuccess
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')

			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_osuccess(bob, "doesn't exist", "become real")
			
			# Can change description so long as you own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_osuccess(bob, "anne", "fred")
			
			# Something we own
			Interface.expects(:do_notify).with(bob, "Message set.").in_sequence(notify)
			set.do_osuccess(bob, "cheese", "bob eat the cheese")
			assert_equal("bob eat the cheese", @db.get(cheese).osucc)
		end
		
		def test_do_ofail
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')

			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_ofail(bob, "doesn't exist", "become real")
			
			# Can change description so long as you own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_ofail(bob, "anne", "fred")
			
			# Something we own
			Interface.expects(:do_notify).with(bob, "Message set.").in_sequence(notify)
			set.do_ofail(bob, "cheese", "bob failed to eat the cheese")
			assert_equal("bob failed to eat the cheese", @db.get(cheese).ofail)			
		end

		def test_do_lock
			# I can't work out *still* how to get ambigous matches!!! So far none of the tests cover this match case!!!
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			exit = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => exit  }) }
			record(exit) {|r| r.merge!( :location => NOTHING, :name => "exit", :flags => TYPE_EXIT, :owner => bob, :next => NOTHING ) }

			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see what you want to lock!").in_sequence(notify)
			set.do_lock(bob, "spaghetti", "sauce")
			
			# Don't control
			Interface.expects(:do_notify).with(bob, "You can't lock that!").in_sequence(notify)
			set.do_lock(bob, "anne", "sauce")
			
			# Ok, now onto the "key" - Doesn't exist!
			Interface.expects(:do_notify).with(bob, "I can't find that key!").in_sequence(notify)
			set.do_lock(bob, "cheese", "sauce")
			
			# Key is not a player or thing
			Interface.expects(:do_notify).with(bob, "Keys can only be players or things.").in_sequence(notify)
			set.do_lock(bob, "cheese", "exit")
			
			# Ok - Do it!
			Interface.expects(:do_notify).with(bob, "Locked.").in_sequence(notify)
			set.do_lock(bob, "cheese", "anne")
			assert_equal(anne, @db.get(cheese).key)
			assert_equal(TYPE_THING, @db.get(cheese).flags)
			
			# Now with antilock
			record(cheese) {|r| r[:key] = NOTHING }
			Interface.expects(:do_notify).with(bob, "Anti-Locked.").in_sequence(notify)
			set.do_lock(bob, "cheese", "!anne")
			assert_equal(anne, @db.get(cheese).key)
			assert_equal(TYPE_THING | ANTILOCK, @db.get(cheese).flags)
		end

		def test_do_unlock
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_unlock(bob, "spaghetti")
			
			# Must own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_unlock(bob, "anne")
			
			# Do it (from normal lock)
			Interface.expects(:do_notify).with(bob, "Locked.").in_sequence(notify)
			set.do_lock(bob, "cheese", "anne")
			Interface.expects(:do_notify).with(bob, "Unlocked.").in_sequence(notify)
			set.do_unlock(bob, "cheese")
			assert_equal(NOTHING, @db.get(cheese).key)
			assert_equal(TYPE_THING, @db.get(cheese).flags)
			
			# Do it from antilock
			Interface.expects(:do_notify).with(bob, "Anti-Locked.").in_sequence(notify)
			set.do_lock(bob, "cheese", "!anne")
			Interface.expects(:do_notify).with(bob, "Unlocked.").in_sequence(notify)
			set.do_unlock(bob, "cheese")
			assert_equal(NOTHING, @db.get(cheese).key)
			assert_equal(TYPE_THING, @db.get(cheese).flags)
		end

		def test_do_unlink
			# I can't work out *still* how to get ambigous matches!!! So far none of the tests cover this match case!!!
			Db.Minimal()
			limbo = 0
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			exit = @db.add_new_record
			jam = @db.add_new_record
			record(place) {|r| r.merge!({ :location => limbo, :name => "place", :contents => bob, :flags => TYPE_ROOM, :exits => exit }) }
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			record(jam) {|r| r.merge!({ :name => "jam", :location => place, :description => "red", :flags => TYPE_THING, :owner => bob, :next => NOTHING }) }
			record(exit) {|r| r.merge!( :location => limbo, :name => "exit", :description => "long", :flags => TYPE_EXIT, :next => NOTHING ) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing doesn't exist or is a player
			Interface.expects(:do_notify).with(bob, "Unlink what?").in_sequence(notify)
			set.do_unlink(bob, "spaghetti")
			Interface.expects(:do_notify).with(bob, "Unlink what?").in_sequence(notify)
			set.do_unlink(bob, "anne")
			
			# Must own
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_unlink(bob, "exit")
			
			# Must be an exit or room
			# But I think only a wizard can hit this logic as the normal match code won't pick up things!
			
			# Do it!
			record(exit) {|r| r[:owner] = bob }
			Interface.expects(:do_notify).with(bob, "Unlinked.").in_sequence(notify)
			set.do_unlink(bob, "exit")
			assert_equal(NOTHING, @db.get(exit).location)
			
			# Do it on a room
			record(place) {|r| r[:owner] = bob }
			Interface.expects(:do_notify).with(bob, "Dropto removed.").in_sequence(notify)
			set.do_unlink(bob, "here")
			assert_equal(NOTHING, @db.get(place).location)
			
			# Remember wizard absolute - Try it on a thing
			record(bob) {|r| r[:flags] = TYPE_PLAYER | WIZARD }
			Interface.expects(:do_notify).with(bob, "You can't unlink that!").in_sequence(notify)
			set.do_unlink(bob, "##{jam}")
			
			# They also have power!
			record(exit) {|r| r[:owner] = anne }
			record(exit) {|r| r[:location] = anne }
			Interface.expects(:do_notify).with(bob, "Unlinked.").in_sequence(notify)
			set.do_unlink(bob, "exit")
			assert_equal(NOTHING, @db.get(exit).location)
		end
		
		def test_do_chown
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			exit = @db.add_new_record
			jam = @db.add_new_record
			record(place) {|r| r.merge!({ :name => "place", :contents => bob, :flags => TYPE_ROOM, :exits => exit }) }
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => jam ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			record(jam) {|r| r.merge!({ :name => "jam", :location => place, :description => "red", :flags => TYPE_THING, :owner => bob, :next => NOTHING }) }
			record(exit) {|r| r.merge!( :name => "exit", :description => "long", :flags => TYPE_EXIT, :owner => anne, :next => NOTHING ) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Person must be a wizard
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_chown(bob, "jam", "anne")
			
			# Missing owning object
			record(bob) {|r| r[:flags] = TYPE_PLAYER | WIZARD }
			Interface.expects(:do_notify).with(bob, "I couldn't find that player.").in_sequence(notify)
			set.do_chown(bob, "jam", "twig")
			
			# Chown on a player
			Interface.expects(:do_notify).with(bob, "Players always own themselves.").in_sequence(notify)
			set.do_chown(bob, "anne", "bob")
			
			# Ok!
			Interface.expects(:do_notify).with(bob, "Owner changed.").in_sequence(notify)
			set.do_chown(bob, "cheese", "anne")
			assert_equal(anne, @db.get(cheese).owner)
			Interface.expects(:do_notify).with(bob, "Owner changed.").in_sequence(notify)
			set.do_chown(bob, "here", "anne")
			assert_equal(anne, @db.get(place).owner)
		end
		
		def test_do_set
			# TODO!!! Brain ran out of steam tonight!!!
		end

		# MOVE THIS SOMEWHERE - DRY
		def record(i)
			record = @db.get(i)

			args = {}
			args[:name] = record.name
			args[:description] = record.description
			args[:location] = record.location
			args[:contents] = record.contents
			args[:exits] = record.exits
			args[:next] = record.next
			args[:key] = record.key
			args[:fail] = record.fail
			args[:succ] = record.succ
			args[:ofail] = record.ofail
			args[:osucc] = record.osucc
			args[:owner] = record.owner
			args[:pennies] = record.pennies
			args[:flags] = record.flags
			args[:password] = record.password

			yield args

			args.each do |key, value|
				case key
				when :name
					record.name = value
				when :description
					record.description = value
				when :location
					record.location = value
				when :contents
					record.contents = value
				when :exits
					record.exits = value
				when :next
					record.next = value
				when :key
					record.key = value
				when :fail
					record.fail = value
				when :succ
					record.succ = value
				when :ofail
					record.ofail = value
				when :osucc
					record.osucc = value
				when :owner
					record.owner = value
				when :pennies
					record.pennies = value
				when :flags
					record.flags = value
				when :password
					record.password = value
				else
					raise("Record - unknown key #{key} with #{value}")
				end
			end

			@db.put(i, record)
		end
    end
end