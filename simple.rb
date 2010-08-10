#!/usr/bin/env ruby

require 'rubygems'
require 'system_timer'
require 'socket'
require 'getopt/std'
require 'rinotify'

class SimpleBot
  def initialize (nick, uname, pass, server, port, channel)
    @defaults = {lambda {|msg| msg =~ /^PING/ } => :handle_ping }
    @channel = channel
    @server = server
    @socket = TCPSocket.open(server, port)
    @nick = nick
    @uname = uname
    if pass then write "PASS #{pass}" end
    write "NICK #{nick}"
    write "USER #{nick} 0 * :#{uname}"
    write "JOIN ##{@channel}"
#   say_to_chan "#{1.chr}ACTION says hello#{1.chr}"

    @callbacks = {}
    reload_conf()
  end

  def get_default_handler (msg)
    @defaults.each_key do |pred|
      if pred.call(msg) then return @defaults[pred] end
    end
    return false
  end

  def handle_ping (msg)
    msg =~ /^PING :(.+)/
    write "PONG :#{$1}"
  end

  def reload_conf
    old = @callbacks
    @callbacks[:chat] = nil
    @callbacks[:private] = nil
    @callbacks[:other] = nil
    @callbacks[:minute] = nil
    begin
      lines = IO.readlines("config.rb")
      eval(lines.join("\n"))
      puts "$$$ reloaded config file $$$"
    rescue 
      puts "$$$ (config.rb): load error in config.rb $$$\n$$$\n #{$!} \n$$$ "
      @callbacks = old
    end
  end

  def write (msg)
    puts msg
    @socket.puts msg
  end

  def say_quietly (msg)
    @socket.puts msg
  end

  def say_to_nick(nick, msg)
    write "PRIVMSG #{nick} :#{msg}"
  end

  def say_to_chan(msg)
    write "PRIVMSG ##{@channel} :#{msg}"
  end
  
  def emote_to_nick(nick, msg)
    say_to_nick nick, "#{1.chr}ACTION #{msg}#{1.chr}"
  end

  def emote_to_chan(msg)
    say_to_chan "#{1.chr}ACTION #{msg}#{1.chr}"
  end

  def minute
    @callbacks[:minute].call
  end

  def run
    until @socket.eof? do
      msg = @socket.gets
      puts msg
      handler = get_default_handler(msg)  #default actions here
      send(handler, msg) if handler
      begin
        if msg =~ /^:([^!]+)!~([^@]+)@([^\s]+)\s+PRIVMSG ##{@channel} :(.*)/
          if @callbacks[:chat]
            @callbacks[:chat].call $1, $2, $3, $4  #nick #user #ip #msg
          end
          #default actions here for channel msgs
        elsif msg =~ /^:([^!]+)!~([^@]+)@([^\s]+)\s+PRIVMSG #{@nick} :(.*)/
          if @callbacks[:private]
            @callbacks[:private].call $1, $2, $3, $4 #nick #user #ip #msg
          end
          #default actions here private messages
        else
          if @callbacks[:other]
            @callbacks[:other].call msg
          end
          #default actions here for other cmds
        end
      rescue
        puts "$$$ runtime error from config.rb $$$\n$$$\n #{$!}\n$$$"
      end
    end
  end

  def quit
    write "PART ##{@channel} :flees"
    write "QUIT"
  end
end

def usage
  puts "Usage: #{$0} [-c server] [-j channel] [-n nick] [-u uname] [-w pw]"
end
ARGV.each do |arg|
  if arg == '--help' || arg == '-h' || arg == '-?'
    usage
    exit 0
  end
end
opts = Getopt::Std.getopts("c:n:w:j:u:")
serv = opts["c"] || "irc.freenode.net"
port = 6667
join = opts["j"] || 'apfelstrudel'
nick = opts["n"] || 'a_monkey'
uname = opts["u"] || 'monkeybot'
pass = opts["w"] || '' 

puts "connecting to '#{serv}' -> '#{join}' as '#{nick}', with pw #{pass}"

bot = SimpleBot.new(nick, uname, pass, serv, port, join)
trap("INT") { bot.quit; exit 0 }

rinotify = RInotify.new
rinotify.add_watch("config.rb", RInotify::MODIFY)
t = Thread.new do
  while (1)
    has_events = rinotify.wait_for_events(2)
    if has_events
      events = nil
      rinotify.each_event { |evt|
        if evt.check_mask(RInotify::MODIFY)
          events = true
        end
      }
      if events then bot.reload_conf end
    end
  end
end

Thread.new do  
  while (1)
    sleep 60
    bot.minute
  end
end

bot.run


