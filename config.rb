@owner = "gs4"
@owner_names = /[gG]ordon/


@callbacks = {
  :chat => lambda { |nick, user, ip, msg|
    if msg =~ @owner_names || msg =~ /@owner/
      say_to_nick @owner, "#{nick}: #{msg}"
    end
    if msg =~ /monkey/
      say_to_nick @owner, "#{nick}: #{msg}"
    end
    if msg.downcase =~ /do a barrel roll/
      emote_to_chan "does a barrel roll"
    end
  },
  :private => lambda { |nick, user, ip, msg|
    msg.strip!
    
    if nick == @owner
      if msg =~ /^say\s(.+)/
        say_to_chan $1
      elsif msg =~ /^emote\s(.+)/
        emote_to_chan $1
      else
        eval(msg)
      end
    else
      say_to_nick @owner, "forwarded message from #{nick} (#{user}@#{ip}) :#{msg}"
    end
  },
  :other => lambda { |msg|
    #server messages
  },
  :minute => lambda {
    puts 'tic'
    if (rand * 90).to_i == 0
      choice = choose_from ["meows", "woofs", "needs a banana", "barks", "moos", "scratches itself", "roars"]
      emote_to_chan choice
    end
  }
}

def choose_from(arr)
  r = (rand * arr.length).to_i
  return arr[r]
end

