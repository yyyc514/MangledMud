require_relative 'helpers'

module MangledMud

  # Provides a collection of methods to move objects and players around the world.
  # @version 1.0
  class Move
    include Helpers

    # @param [Db] db the current database instance
    # @param [Object] notifier An object with method do_notify(player_id, string), the method will be called to send notifications back to the player invoking the command/action
    def initialize(db, notifier)
      @db = db
      @notifier = notifier
      @utils = Utils.new(@db)
      @speech = Speech.new(@db, notifier)
      @predicates = Predicates.new(@db, notifier)
      @match = Match.new(@db, notifier)
    end

    # Moves a record to a new location.
    # @param [Number] what the db index of the old object.
    # @param [Number] where the db index of the new location for the object.
    def moveto(what, where)
      loc = @db[what].location

      # remove what from old loc
      if (loc != NOTHING)
        @db[loc].contents = @utils.remove_first(@db[loc].contents, what)
      end

      # test for special cases
      case where
      when NOTHING
        @db[what].location = NOTHING
        return # NOTHING doesn't have contents
      when HOME
        where = @db[what].exits # home
      end

      # now put what in where
      @db[what].next = @db[where].contents
      @db[where].contents = what
      @db[what].location = where
    end

    # Moves a player to a new location, sending proper travel messages and managing sticky/dark room features, calls back to the notifier passed into the initializer
    # @param [Number] player the db index of the player that is traveling.
    # @param [Number] loc the db index of the room the player is traveling into.
    def enter_room(player, loc)
      # check for room == HOME
      loc = @db[player].exits if (loc == HOME) # home

      # get old location
      old = @db[player].location

      # check for self-loop
      # self-loops don't do move or other player notification
      # but you still get autolook and penny check
      if (loc != old)
        if (old != NOTHING)
          # notify others unless DARK
          if (!is_dark(old) && !is_dark(player))
            @speech.notify_except(@db[old].contents, player, Phrasebook.lookup('player-left', @db[player].name))
          end
        end

        # go there
        moveto(player, loc)

        # if old location has STICKY dropto, send stuff through it
        if (old != NOTHING && (dropto = @db[old].location) != NOTHING && (is_sticky(old)))
          maybe_dropto(old, dropto)
        end

        # tell other folks in new location if not DARK
        if (!is_dark(loc) && !is_dark(player))
          @speech.notify_except(@db[loc].contents, player, Phrasebook.lookup('player-arrived', @db[player].name))
        end
      end

      # autolook
      Look.new(@db, @notifier).look_room(player, loc)

      # check for pennies

      # Added to allow mocking/control over when someone gets a penny
      give_penny = (Game.do_rand() % PENNY_RATE) == 0

      if (!@predicates.controls(player, loc) && (@db[player].pennies <= MAX_PENNIES) && give_penny)
        @notifier.do_notify(player, Phrasebook.lookup('found-a-penny'))
        @db[player].pennies = @db[player].pennies + 1
      end
    end

    # Sends a record to it's stored home location (if applicable), calling back on the notifier passed into the initializer
    # @param [Number] thing the db index of the record to send home.
    def send_home(thing)
      case typeof(thing)
      when TYPE_PLAYER
        # send his possessions home first!
        # that way he sees them when he arrives
        send_contents(thing, HOME)
        enter_room(thing, @db[thing].exits) # home
      when TYPE_THING
        moveto(thing, @db[thing].exits) # home
      else
        # no effect
      end
    end
  
    # Determines if a player is making a legal move. Legal move is one of the exits in the room or "home" keyword.
    # @param [Number] player the db index of the player trying to move.
    # @param [String] direction the direction the player is trying to move.
    # @return [true, false] true if the player can move to specified location, false otherwise.
    def can_move(player, direction)
      return true if (direction.casecmp("home") == 0)

      # otherwise match on exits
      @match.init_match(player, direction, TYPE_EXIT)
      @match.match_exit()

      return @match.last_match_result() != NOTHING
    end

    # Moves a player through a given exit, or keyword "home". Notifies player and room of consequence through calling back on the notifier passed into the initializer
    # @param [Number] player the db index of the player trying to move.
    # @param [String] direction the direction the player is trying to move.
    def do_move(player, direction)
      if (direction and direction.casecmp("home") == 0)
        # send him home
        # but steal all his possessions
        loc = @db[player].location
        if (loc != NOTHING)
          # tell everybody else
          @speech.notify_except(@db[loc].contents, player, "#{@db[player].name} goes home.")
        end
        # give the player the messages
        @notifier.do_notify(player, Phrasebook.lookup('no-place-like-home'))
        @notifier.do_notify(player, Phrasebook.lookup('no-place-like-home'))
        @notifier.do_notify(player, Phrasebook.lookup('no-place-like-home'))
        @notifier.do_notify(player, Phrasebook.lookup('wake-up-home'))
        send_home(player)
      else
        # find the exit
        @match.init_match_check_keys(player, direction, TYPE_EXIT)
        @match.match_exit()
        exit = @match.match_result()
        case exit
        when NOTHING
          @notifier.do_notify(player, Phrasebook.lookup('bad-direction'))
        when AMBIGUOUS
          @notifier.do_notify(player, Phrasebook.lookup('which-way'))
        else
          # we got one
          # check to see if we got through
          if (@predicates.can_doit(player, exit, "You can't go that way."))
            enter_room(player, @db[exit].location)
          end
        end
      end
    end

    # Attempt to relocate an object to a player's inventory. Notifies player and room of consequence through calling back on the notifier passed into the initializer
    # @param [Number] player the db index of the player trying to take the object.
    # @param [String] what the name of the object that is being taken.
    def do_get(player, what)
      @match.init_match_check_keys(player, what, TYPE_THING)
      @match.match_neighbor()
      @match.match_exit()
      @match.match_absolute() if (is_wizard(player)) # the wizard has long fingers

      thing = @match.noisy_match_result()
      if (thing != NOTHING)
        if (@db[thing].location == player)
          @notifier.do_notify(player, Phrasebook.lookup('already-have-it'))
          return
        end
        case typeof(thing)
        when TYPE_THING
          if (@predicates.can_doit(player, thing, "You can't pick that up."))
            moveto(thing, player)
            @notifier.do_notify(player, Phrasebook.lookup('taken'))
          end
        when TYPE_EXIT
          if (!@predicates.controls(player, thing))
            @notifier.do_notify(player, Phrasebook.lookup('bad-pickup'))
          elsif (@db[thing].location != NOTHING)
            @notifier.do_notify(player, Phrasebook.lookup('no-get-linked-exit'))
          else
            # take it out of location
            loc = getloc(player)
            return if (loc == NOTHING)
            if (!@utils.member(thing, @db[loc].exits))
              @notifier.do_notify(player, Phrasebook.lookup('no-get-exit-elsewhere'))
              return
            end
            @db[loc].exits = @utils.remove_first(@db[loc].exits, thing)
            @db[thing].next = @db[player].contents
            @db[player].contents = thing
            @db[thing].location = player
            @notifier.do_notify(player, Phrasebook.lookup('exit-taken'))
          end
        else
          @notifier.do_notify(player, Phrasebook.lookup('cant-take'))
        end
      end
    end

    # Attempt to relocate an object to the room from the player's inventory. Notifies player (and room, under certain conditions) of consequence through
    # calling back on the notifier passed into the initializer
    # @param [Number] player the db index of the player trying to drop the object.
    # @param [String] name the name of the object that is being dropped.
    def do_drop(player, name)
      loc = getloc(player)
      return if (loc == NOTHING)

      @match.init_match(player, name, TYPE_THING)
      @match.match_possession()
      thing = @match.match_result()

      case thing
      when NOTHING
        @notifier.do_notify(player, Phrasebook.lookup('dont-have-it'))
      when AMBIGUOUS
        @notifier.do_notify(player, Phrasebook.lookup('which'))
      else
        if (@db[thing].location != player)
          # Shouldn't ever happen.
          @notifier.do_notify(player, Phrasebook.lookup('cant-drop-that'))
        elsif (exit?(thing))
          # special behavior for exits
          if (!@predicates.controls(player, loc))
            @notifier.do_notify(player, Phrasebook.lookup('no-drop-exit-here'))
            return
          end
          # else we can put it down
          moveto(thing, NOTHING) # take it out of the pack

          @db[thing].next = @db[loc].exits
          @db[loc].exits = thing
          @notifier.do_notify(player, Phrasebook.lookup('exit-dropped'))
        elsif (is_temple(loc))
          # sacrifice time
          send_home(thing)

          @notifier.do_notify(player, Phrasebook.lookup('consumed-in-flame', @db[thing].name))
          @speech.notify_except(@db[loc].contents, player, Phrasebook.lookup('sacrifices', @db[player].name, @db[thing].name))

          # check for reward
          if (!@predicates.controls(player, thing))
            reward = @db[thing].pennies
            if (reward < 1 || @db[player].pennies > MAX_PENNIES)
              reward = 1
            elsif (reward > MAX_OBJECT_ENDOWMENT)
              reward = MAX_OBJECT_ENDOWMENT
            end

            @db[player].pennies = @db[player].pennies + reward
            if reward == 1
              @notifier.do_notify(player, Phrasebook.lookup('you-have-received-penny'))
            else
              @notifier.do_notify(player, Phrasebook.lookup('you-have-received-pennies', reward))
            end
          end
        elsif (is_sticky(thing))
          send_home(thing)
          @notifier.do_notify(player, Phrasebook.lookup('dropped'))
        elsif (@db[loc].location != NOTHING && !is_sticky(loc))
          # location has immediate dropto
          moveto(thing, @db[loc].location)
          @notifier.do_notify(player, Phrasebook.lookup('dropped'))
        else
          moveto(thing, loc)
          @notifier.do_notify(player, Phrasebook.lookup('dropped'))
          @speech.notify_except(@db[loc].contents, player, Phrasebook.lookup('dropped-thing', @db[player].name, @db[thing].name))
        end
      end
    end

    private

    # Helper function that ensures sets of objects (held, etc.) move together.  Manages STICKY attribute with moving objects as well.
    # @param [Number] loc the location that contains the first of the linked objects (with next field, managed by enum function).
    # @param [Number[ dest the db index of the destination room to move the linked objects.
    def send_contents(loc, dest)
      first = @db[loc].contents
      @db[loc].contents = NOTHING

      # blast locations of everything in list
      enum(first).each {|item| @db[item].location = NOTHING }

      while (first != NOTHING)
        rest = @db[first].next
        if (!thing?(first))
          moveto(first, loc)
        else
          moveto(first, is_sticky(first) ? HOME : dest)
        end
        first = rest
      end
      @db[loc].contents = @utils.reverse(@db[loc].contents)
    end

    def maybe_dropto(loc, dropto)
      return if (loc == dropto) # bizarre special case

      # check for players
      enum(@db[loc].contents).each do |i|
        return if is_player(i)
      end

      # no players, send everything to the dropto
      send_contents(loc, dropto)
    end

  end
end
