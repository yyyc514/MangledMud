require 'rubygems'
require 'mocha'
require 'test/unit'
require 'defines'
require 'tinymud'
require 'pp'

module TinyMud
    class TestPredicates < Test::Unit::TestCase
		def setup
			@db = TinyMud::Db.new
		end

		def teardown
			@db.free()
		end

		# where must be valid, the where must be a room, who must either control (own) where or where is LINK_OK
		def test_can_link_to
			Db.Minimal()

			# Make a minimal new player - This should be a helper at some point?
			player_ref = Player.new.create_player("bob", "pwd")
			assert_equal(2, player_ref)

			pred = Predicates.new
			assert_equal(0, pred.can_link_to(0, -1)) # Where < 0
			assert_equal(0, pred.can_link_to(0, @db.length)) # where > db_top
			assert_equal(0, pred.can_link_to(0, 1)) # where points to non-room (wizard)

			assert_equal(1, pred.can_link_to(1, 0)) # who = Wizard = 1 = controls all
			
			assert_equal(0, pred.can_link_to(player_ref, 0)) # who = "bob" = 2 = controls nothing, limbo no LINK_OK
			record(0) {|r| r[:flags] = TYPE_ROOM | LINK_OK }
			assert_equal(1, pred.can_link_to(player_ref, 0)) # who = "bob" = 2 = controls nothing, limbo LINK_OK

			# Create an object "bob" owns
			obj_ref = @db.add_new_record
			record(obj_ref) {|r| r.merge!({:flags => TYPE_ROOM, :owner => player_ref}) }
			assert_equal(1, pred.can_link_to(player_ref, obj_ref)) # who = "bob" = 2 = controls object

			# Bob doesn't own, but linking is allowed
			record(obj_ref) {|r| r.merge!({:flags => TYPE_ROOM | LINK_OK, :owner => 1}) }
			assert_equal(1, pred.can_link_to(player_ref, obj_ref)) # who = "bob" = 2 = doesn't control object but it allows links
		end
		
		def test_could_doit
			Db.Minimal()
			wizard = 1
			uninitialized_thing_ref = @db.add_new_record
			record(uninitialized_thing_ref) {|r| r.merge!({:flags => TYPE_PLAYER, :location => NOTHING }) }
			
			pred = Predicates.new

			# if thing isn't a room then its location can't be nothing
			assert_equal(0, pred.could_doit(-1, uninitialized_thing_ref));
			
			# if key is nothing then could!
			record(uninitialized_thing_ref) {|r| r.merge!({ :flags => TYPE_ROOM, :key => NOTHING }) }
			assert_equal(1, pred.could_doit(-1, uninitialized_thing_ref));
			
			# If the player is the key, return based on antilock flag - i.e. item needs player
			record(uninitialized_thing_ref) {|r| r.merge!({ :key => wizard, :flags => TYPE_ROOM }) }
			assert_equal(1, pred.could_doit(wizard, uninitialized_thing_ref));
			record(uninitialized_thing_ref) {|r| r.merge!({ :key => wizard, :flags => TYPE_ROOM | ANTILOCK }) }
			assert_equal(0, pred.could_doit(wizard, uninitialized_thing_ref));
			
			# If the player isn't the key, and key isn't a member of the players contents
			record(uninitialized_thing_ref) {|r| r.merge!({ :key => 10, :flags => TYPE_ROOM }) }
			assert_equal(0, pred.could_doit(wizard, uninitialized_thing_ref));
			record(uninitialized_thing_ref) {|r| r.merge!({ :flags => TYPE_ROOM | ANTILOCK }) }
			assert_equal(1, pred.could_doit(wizard, uninitialized_thing_ref));

			# If the player isn't the key, and the key is a member of the players contents
			record(uninitialized_thing_ref) {|r| r.merge!({ :key => uninitialized_thing_ref, :flags => TYPE_ROOM }) }
			record(wizard) {|r| r.merge!({ :contents => uninitialized_thing_ref }) }
			assert_equal(1, pred.could_doit(wizard, uninitialized_thing_ref));
			record(uninitialized_thing_ref) {|r| r.merge!({ :flags => TYPE_ROOM | ANTILOCK }) }
			assert_equal(0, pred.could_doit(wizard, uninitialized_thing_ref));
		end
		
		def test_can_doit
			Db.Minimal()
			uninitialized_thing_ref = @db.add_new_record
			record(uninitialized_thing_ref) {|r| r.merge!({:flags => TYPE_PLAYER, :location => NOTHING }) }

			wizard = 1
			pred = Predicates.new

			# If player location nothing
			record(wizard) {|r| r.merge!({ :location => NOTHING }) }
			assert_equal(0, pred.can_doit(wizard, -1, ""))
			
			# If can't do-it with thing, use either things fail message or the default
			Interface.expects(:do_notify).with(wizard, "Sandwich")
			record(wizard) {|r| r.merge!({ :location => 0 }) }
			record(uninitialized_thing_ref) {|r| r[:fail] = "Sandwich" }
			assert_equal(0, pred.can_doit(wizard, uninitialized_thing_ref, "Ooops"))
			Interface.expects(:do_notify).with(wizard, "Ooops")
			record(uninitialized_thing_ref) {|r| r[:fail] = nil }
			assert_equal(0, pred.can_doit(wizard, uninitialized_thing_ref, "Ooops"))
			
			# Lastly, if ofail is set on the thing then all "contents" in the things location should be notified, except player
			player_ref = Player.new.create_player("bob", "pwd")
			record(uninitialized_thing_ref) {|r| r[:ofail] = "Fails Eating Sandwich" }
			record(0) {|r| r[:contents] = player_ref }
			Interface.expects(:do_notify).with(wizard, "Ooops")
			Interface.expects(:do_notify).with(player_ref, "Wizard Fails Eating Sandwich");
			assert_equal(0, pred.can_doit(wizard, uninitialized_thing_ref, "Ooops"))
			
			# If can do it (set player to key) then use success message if present
			record(uninitialized_thing_ref) {|r| r.merge!({ :key => wizard, :flags => TYPE_ROOM }) }
			record(uninitialized_thing_ref) {|r| r[:succ] = "Eat Sandwich" }
			Interface.expects(:do_notify).with(wizard, "Eat Sandwich")
			assert_equal(1, pred.can_doit(wizard, uninitialized_thing_ref, "Ooops"))
			record(uninitialized_thing_ref) {|r| r[:osucc] = "He Eat Sandwich" }
			Interface.expects(:do_notify).with(wizard, "Eat Sandwich")
			Interface.expects(:do_notify).with(player_ref, "Wizard He Eat Sandwich")
			assert_equal(1, pred.can_doit(wizard, uninitialized_thing_ref, "Ooops"))
		end

		def test_can_see
			Db.Minimal()
			player_ref = Player.new.create_player("bob", "pwd")
			wizard = 1
			pred = Predicates.new
			# player is thing
			assert_equal(0, pred.can_see(wizard, wizard, -1))
			# thing is an exit
			record(0) {|r| r[:flags] = TYPE_EXIT }
			assert_equal(0, pred.can_see(wizard, 0, -1))
			# Can see location, not dark
			record(0) {|r| r[:flags] = TYPE_ROOM }
			assert_equal(1, pred.can_see(wizard, 0, 1))
			# Is dark, but a wizard - controls everything
			record(0) {|r| r[:flags] = TYPE_ROOM | DARK }
			assert_equal(1, pred.can_see(wizard, 0, 1))
			# Is dark, but the player owns the item
			record(0) {|r| r[:owner] = player_ref }
			assert_equal(1, pred.can_see(player_ref, 0, 1))
			# Can't see location, but wizard
			assert_equal(1, pred.can_see(wizard, 0, 0))
			# Can't see location, but owns
			assert_equal(1, pred.can_see(player_ref, 0, 0))
			# Can't see location, but doesn't own
			record(0) {|r| r[:owner] = player_ref + 1 }
			assert_equal(0, pred.can_see(player_ref, 0, 0))
		end

		def test_controls
			Db.Minimal()
			player_ref = Player.new.create_player("bob", "pwd")
			wizard = 1
			pred = Predicates.new
			assert_equal(0, pred.controls(0, -1)) # Where < 0
			assert_equal(0, pred.controls(0, @db.length)) # where > db_top
			# Wizard controls everything
			assert_equal(1, pred.controls(wizard, 0))
			assert_equal(1, pred.controls(wizard, player_ref))
			# Player controls only if owns
			assert_equal(0, pred.controls(player_ref, 0))
			record(0) {|r| r[:owner] = player_ref }
			assert_equal(1, pred.controls(player_ref, 0))
		end
		
		def test_can_link
			Db.Minimal()
			player_ref = Player.new.create_player("bob", "pwd")
			wizard = 1
			pred = Predicates.new
			# Can link to something only if its an exit going to nothing
			record(0) {|r| r.merge!({:flags => TYPE_EXIT, :location => 22}) }
			assert_equal(0, pred.can_link(player_ref, 0))
			record(0) {|r| r[:location] = NOTHING }
			assert_equal(1, pred.can_link(player_ref, 0))
			# Or the player controls
			record(0) {|r| r[:flags] = TYPE_ROOM }
			assert_equal(1, pred.can_link(wizard, 0)) # Wizard controls everything
			assert_equal(0, pred.can_link(player_ref, 0))
			record(0) {|r| r[:owner] = player_ref }
			assert_equal(1, pred.can_link(player_ref, 0))
		end

		def test_payfor
			Db.Minimal()
			player_ref = Player.new.create_player("bob", "pwd")
			wizard = 1
			pred = Predicates.new
			# Wizard is automatic
			assert_equal(0, @db.get(wizard).pennies)
			assert_equal(1, pred.payfor(wizard, 123))
			assert_equal(0, @db.get(wizard).pennies)
			# If player has the money then ok and do
			record(player_ref) {|r| r[:pennies] = 123 }
			assert_equal(1, pred.payfor(player_ref, 23))
			assert_equal(100, @db.get(player_ref).pennies)
			# Else no
			assert_equal(0, pred.payfor(player_ref, 101))
		end
		
		def test_ok_name
			pred = Predicates.new
			assert_equal(0, pred.ok_name(nil))
			assert_equal(0, pred.ok_name(0.chr))
			assert_equal(0, pred.ok_name(LOOKUP_TOKEN))
			assert_equal(0, pred.ok_name(NUMBER_TOKEN))
			assert_equal(0, pred.ok_name("me"))
			assert_equal(0, pred.ok_name("home"))
			assert_equal(0, pred.ok_name("here"))
			assert_equal(1, pred.ok_name("cheese"))
		end
		
		def test_ok_player_name
			Db.Minimal()
			player_ref = Player.new.create_player("bob", "pwd")
			pred = Predicates.new
			# Must be an ok name
			assert_equal(0, pred.ok_player_name(nil))
			assert_equal(0, pred.ok_player_name(0.chr))
			assert_equal(0, pred.ok_player_name(LOOKUP_TOKEN))
			assert_equal(0, pred.ok_player_name(NUMBER_TOKEN))
			assert_equal(0, pred.ok_player_name("me"))
			assert_equal(0, pred.ok_player_name("home"))
			assert_equal(0, pred.ok_player_name("here"))
			# Musn't contain a non printing character
			assert_equal(0, pred.ok_player_name("he#{4.chr}lp"))
			# Musn't already be used
			assert_equal(0, pred.ok_player_name("Wizard"))
			assert_equal(0, pred.ok_player_name("bob"))
			assert_equal(1, pred.ok_player_name("bab"))
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