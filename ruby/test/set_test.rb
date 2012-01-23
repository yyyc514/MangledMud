require 'rubygems'
require 'test/unit'
require 'mocha'
require_relative 'defines'
require_relative 'include'
require_relative 'helpers'
require 'pp'

module TinyMud
    class TestSet < Test::Unit::TestCase
		
		include TestHelpers
		
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
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING, :fail => "fail"  }) }
			
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
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING, :succ => "success"  }) }
			
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
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING, :osucc => "osuccess"  }) }
			
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
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING, :ofail => "ofail"  }) }
			
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
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			anna = Player.new.create_player("anna", "sponge")
			cheese = @db.add_new_record
			cheese2 = @db.add_new_record
			exit = @db.add_new_record
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anna ) }
			record(anna) {|r| r.merge!( :contents => NOTHING, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => cheese2  }) }
			record(cheese2) {|r| r.merge!({ :name => "cheesey", :location => bob, :description => "smelly", :flags => TYPE_THING, :owner => bob, :next => exit  }) }
			record(exit) {|r| r.merge!( :location => bob, :name => "exit", :flags => TYPE_EXIT, :owner => bob, :next => NOTHING ) }

			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing doesn't exist
			Interface.expects(:do_notify).with(bob, "I don't see what you want to lock!").in_sequence(notify)
			set.do_lock(bob, "spaghetti", "sauce")
			
			# Don't control
			Interface.expects(:do_notify).with(bob, "You can't lock that!").in_sequence(notify)
			set.do_lock(bob, "anne", "sauce")
			
			# Ambiguous
			Interface.expects(:do_notify).with(bob, "I don't know which one you want to lock!").in_sequence(notify)
			set.do_lock(bob, "che", "anne")
			Interface.expects(:do_notify).with(bob, "I don't know which key you want!").in_sequence(notify)
			set.do_lock(bob, "cheese", "an")

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
			Db.Minimal()
			limbo = 0
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			exit = @db.add_new_record
			exit2 = @db.add_new_record
			jam = @db.add_new_record
			record(place) {|r| r.merge!({ :location => limbo, :name => "place", :contents => bob, :flags => TYPE_ROOM, :exits => exit }) }
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			record(jam) {|r| r.merge!({ :name => "jam", :location => place, :description => "red", :flags => TYPE_THING, :owner => bob, :next => NOTHING }) }
			record(exit) {|r| r.merge!( :location => limbo, :name => "exit", :description => "long", :flags => TYPE_EXIT, :next => exit2 ) }
			record(exit2) {|r| r.merge!( :location => limbo, :name => "exitw", :description => "w", :flags => TYPE_EXIT, :next => NOTHING ) }
			
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

			# Ambiguous
			Interface.expects(:do_notify).with(bob, "I don't know which one you mean!").in_sequence(notify)
			set.do_unlink(bob, "ex")
			
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
			place = @db.add_new_record
			bob = Player.new.create_player("bob", "sprout")
			anne = Player.new.create_player("anne", "treacle")
			cheese = @db.add_new_record
			record(place) {|r| r.merge!({ :name => "place", :contents => bob, :flags => TYPE_ROOM, :owner => bob }) }
			record(bob) {|r| r.merge!( :contents => cheese, :location => place, :next => anne ) }
			record(anne) {|r| r.merge!( :contents => NOTHING, :location => place, :next => NOTHING ) }
			record(cheese) {|r| r.merge!({ :name => "cheese", :location => bob, :description => "wiffy", :flags => TYPE_THING, :owner => bob, :next => NOTHING  }) }
			
			set = TinyMud::Set.new
			notify = sequence('notify')
			
			# Thing must exist
			Interface.expects(:do_notify).with(bob, "I don't see that here.").in_sequence(notify)
			set.do_set(bob, "sock", nil)
			
			# Check unknown flags - Need not be a wizard at this point
			Interface.expects(:do_notify).with(bob, "I don't recognized that flag.").in_sequence(notify)
			# This confirms restricted building is disabled (I have not tested for it)
			# If this fails then need to write loads more tests
			set.do_set(bob, "cheese", "BUILDER")

			# Fail to set a flag
			Interface.expects(:do_notify).with(bob, "You must specify a flag to set.").in_sequence(notify)
			set.do_set(bob, "cheese", "")
			
			# Only wizards can change anything, restrictions on normal players
			# Can't set wizard flag
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_set(bob, "cheese", "WIZARD")
			# Or Temple
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_set(bob, "cheese", "TEMPLE")
			# Or dark if thing isn't a room
			Interface.expects(:do_notify).with(bob, "Permission denied.").in_sequence(notify)
			set.do_set(bob, "cheese", "DARK")
			
			# Can set rooms as dark (as a non wizard) (if own)
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify)
			set.do_set(bob, "here", "DARK")
			assert_equal(TYPE_ROOM | DARK, @db.get(place).flags)
			# And even the reverse
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "here", "!DARK")
			assert_equal(TYPE_ROOM, @db.get(place).flags)
			
			# Wizards can do the above (but there are no checks on dest. e.g. a wizard cheese!)
			record(bob) {|r| r[:flags] = TYPE_PLAYER | WIZARD }
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify)
			set.do_set(bob, "cheese", "WIZARD")
			assert_equal(TYPE_THING | WIZARD, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify)
			set.do_set(bob, "cheese", "TEMPLE")
			assert_equal(TYPE_THING | TEMPLE | WIZARD, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify)
			set.do_set(bob, "cheese", "DARK")
			assert_equal(TYPE_THING | TEMPLE | WIZARD | DARK, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify)
			set.do_set(bob, "cheese", "STICKY")
			assert_equal(TYPE_THING | TEMPLE | WIZARD | DARK | STICKY, @db.get(cheese).flags)
			# Reverse also true
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "cheese", "!STICKY")
			assert_equal(TYPE_THING | TEMPLE | WIZARD | DARK, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "cheese", "!DARK")
			assert_equal(TYPE_THING | TEMPLE | WIZARD, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "cheese", "!TEMPLE")
			assert_equal(TYPE_THING | WIZARD, @db.get(cheese).flags)
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "cheese", "!WIZARD")
			assert_equal(TYPE_THING, @db.get(cheese).flags)
			
			# Can't lower yourself
			Interface.expects(:do_notify).with(bob, "You cannot make yourself mortal.").in_sequence(notify)
			set.do_set(bob, "bob", "!WIZARD")
			
			# Can convert to wizard
			Interface.expects(:do_notify).with(bob, "Flag set.").in_sequence(notify) # Poor message
			set.do_set(bob, "anne", "WIZARD")
			
			# Can convert back to normal
			Interface.expects(:do_notify).with(bob, "Flag reset.").in_sequence(notify)
			set.do_set(bob, "anne", "!WIZARD")
		end
    end
end