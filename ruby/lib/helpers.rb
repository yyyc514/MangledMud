require_relative 'constants'

module Helpers

  # Build an enumerator which loops from dbref, through its .next links
  def enum(dbref)
    Enumerator.new do |yielder|
      while (dbref != TinyMud::NOTHING)
        yielder.yield dbref
        dbref = @db[dbref].next
      end
    end
  end

  def is_player(item)
    ((@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_PLAYER)
  end

  def is_thing(item)
    ((@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_THING)
  end

  def is_temple(item)
    ((@db[item].flags & TinyMud::TEMPLE) != 0)
  end

  def is_sticky(item)
    ((@db[item].flags & TinyMud::STICKY) != 0)
  end

  def is_link_ok(item)
    ((@db[item].flags & TinyMud::LINK_OK) != 0)
  end

  def is_antilock(item)
    ((@db[item].flags & TinyMud::ANTILOCK) != 0)
  end

  def typeof(item)
    (@db[item].flags & TinyMud::TYPE_MASK)
  end

  def room?(item)
    (@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_ROOM
  end

  def player?(item)
    (@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_PLAYER
  end

  def thing?(item)
    (@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_THING
  end

  def exit?(item)
    (@db[item].flags & TinyMud::TYPE_MASK) == TinyMud::TYPE_EXIT
  end

  def is_wizard(item)
    ((@db[item].flags & TinyMud::WIZARD) != 0)
  end
  
  def is_builder(item)
    ((@db[item].flags & (TinyMud::WIZARD | TinyMud::BUILDER)) != 0)
  end

  def is_dark(item)
    ((@db[item].flags & TinyMud::DARK) != 0)
  end

  def getloc(thing)
    @db[thing].location
  end
end
