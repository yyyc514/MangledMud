require_relative 'helpers'

module TinyMud
  class Move
    include Helpers

    def initialize(db)
      @db = db
      @utils = Utils.new(@db)
      @speech = Speech.new(@db)
      @predicates = Predicates.new(@db)
      @match = Match.new(@db)
    end

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
                  @speech.notify_except(@db[old].contents, player, "#{@db[player].name} has left.")
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
              @speech.notify_except(@db[loc].contents, player, "#{@db[player].name} has arrived.")
          end
      end
  
      # autolook
      Look.new(@db).look_room(player, loc)
  
      # check for pennies
  
      # Added to allow mocking/control over when someone gets a penny
      give_penny = (Game.do_rand() % PENNY_RATE) == 0

      if (!@predicates.controls(player, loc) && (@db[player].pennies <= MAX_PENNIES) && give_penny)
          Interface.do_notify(player, "You found a penny!")
          @db[player].pennies = @db[player].pennies + 1
      end
    end
    
    def send_home(thing)
      case typeof(thing)
        when TYPE_PLAYER
          # send his possessions home first!
          # that way he sees them when he arrives
          send_contents(thing, HOME)
          enter_room(thing, @db[thing].exits) # home
        when TYPE_THING
          moveto(thing, @db[thing].exits)	# home
        else
          # no effect
      end
    end
    
    def can_move(player, direction)
      return true if (direction.casecmp("home") == 0)
  
      # otherwise match on exits
      @match.init_match(player, direction, TYPE_EXIT)
      @match.match_exit()

      return @match.last_match_result() != NOTHING
    end

    def do_move(player, direction)
      if (direction.casecmp("home") == 0)
        # send him home
        # but steal all his possessions
        loc = @db[player].location
        if (loc != NOTHING)
            # tell everybody else
            @speech.notify_except(@db[loc].contents, player, "#{@db[player].name} goes home.")
        end
        # give the player the messages
        Interface.do_notify(player, "There's no place like home...")
        Interface.do_notify(player, "There's no place like home...")
        Interface.do_notify(player, "There's no place like home...")
        Interface.do_notify(player, "You wake up back home, without your possessions.")
        send_home(player)
      else
        # find the exit
        @match.init_match_check_keys(player, direction, TYPE_EXIT)
        @match.match_exit()
        exit = @match.match_result()
        case exit
          when NOTHING
            Interface.do_notify(player, "You can't go that way.")
          when AMBIGUOUS
            Interface.do_notify(player, "I don't know which way you mean!")
          else
            # we got one
            # check to see if we got through
            if (@predicates.can_doit(player, exit, "You can't go that way."))
              enter_room(player, @db[exit].location)
            end
        end
      end
    end
    
    def do_get(player, what) 
      @match.init_match_check_keys(player, what, TYPE_THING)
      @match.match_neighbor()
      @match.match_exit()
      @match.match_absolute() if (is_wizard(player)) # the wizard has long fingers
  
      thing = @match.noisy_match_result()
      if (thing != NOTHING)
        if (@db[thing].location == player)
            Interface.do_notify(player, "You already have that!")
            return
        end
        case typeof(thing)
          when TYPE_THING
            if (@predicates.can_doit(player, thing, "You can't pick that up."))
                moveto(thing, player)
                Interface.do_notify(player, "Taken.")
            end
          when TYPE_EXIT
            if (!@predicates.controls(player, thing))
                Interface.do_notify(player, "You can't pick that up.")
            elsif (@db[thing].location != NOTHING)
                Interface.do_notify(player, "You can't pick up a linked exit.")
            else
                # take it out of location
                loc = getloc(player)
                return if (loc == NOTHING)
                if (!@utils.member(thing, @db[loc].exits))
                    Interface.do_notify(player, "You can't pick up an exit from another room.")
                    return
                end
                @db[loc].exits = @utils.remove_first(@db[loc].exits, thing)
                @db[thing].next = @db[player].contents
                @db[player].contents = thing
                @db[thing].location = player
                Interface.do_notify(player, "Exit taken.")
            end
          else
            Interface.do_notify(player, "You can't take that!")
        end
      end
    end
    
    def do_drop(player, name)
      loc = getloc(player)
      return if (loc == NOTHING)
  
      @match.init_match(player, name, TYPE_THING)
      @match.match_possession()
      thing = @match.match_result()

      case thing
        when NOTHING
          Interface.do_notify(player, "You don't have that!")
        when AMBIGUOUS
          Interface.do_notify(player, "I don't know which you mean!")
        else
          if (@db[thing].location != player)
              # Shouldn't ever happen. 
              Interface.do_notify(player, "You can't drop that.")
          elsif (exit?(thing))
              # special behavior for exits 
              if (!@predicates.controls(player, loc))
                Interface.do_notify(player, "You can't put an exit down here.")
                return
              end
              # else we can put it down 
              moveto(thing, NOTHING) # take it out of the pack 

              @db[thing].next = @db[loc].exits
              @db[loc].exits = thing
              Interface.do_notify(player, "Exit dropped.")
          elsif (is_temple(loc))
              # sacrifice time 
              send_home(thing)

              Interface.do_notify(player, "#{@db[thing].name} is consumed in a burst of flame!")
              @speech.notify_except(@db[loc].contents, player, "#{@db[player].name} sacrifices #{@db[thing].name}.")
      
              # check for reward 
              if (!@predicates.controls(player, thing))
                  reward = @db[thing].pennies
                  if (reward < 1 || @db[player].pennies > MAX_PENNIES)
                      reward = 1
                  elsif (reward > MAX_OBJECT_ENDOWMENT)
                      reward = MAX_OBJECT_ENDOWMENT
                  end
          
                  @db[player].pennies = @db[player].pennies + reward
                  Interface.do_notify(player, "You have received #{reward} #{reward == 1 ? "penny" : "pennies"} for your sacrifice.")
              end
          elsif (is_sticky(thing))
              send_home(thing)
              Interface.do_notify(player, "Dropped.")
          elsif (@db[loc].location != NOTHING && !is_sticky(loc))
              # location has immediate dropto 
              moveto(thing, @db[loc].location)
              Interface.do_notify(player, "Dropped.")
          else
              moveto(thing, loc)
              Interface.do_notify(player, "Dropped.")
              @speech.notify_except(@db[loc].contents, player, "#{@db[player].name} dropped #{@db[thing].name}.")
          end
      end
    end

    private

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
