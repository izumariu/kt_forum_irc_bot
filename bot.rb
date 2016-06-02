#!/usr/bin/ruby
require 'net/http'
require 'rubygems'
require 'json'
require 'cinch' #gem install cinch

$api_key = ""
File.open("../kt_irc_bot_data/api_key.txt","r").each_line {|f| $api_key << f.chomp}
$main_chat_id = ""
File.open("../kt_irc_bot_data/mcid.txt","r").each_line {|f| $main_chat_id << f.chomp}

escapes = {
	#" " => "%20",
	#"!" => "%21",
	"\""=> "%22",
	"#" => "%23",
	"$" => "%24",
	"%" => "%25",
	"&" => "%26",
	"\'"=> "%27",
	"(" => "%28",
	")" => "%29",
	"*" => "%2A",
	"+" => "%2B",
	"," => "%2C",
	"-" => "%2D",
	"." => "%2E",
	"\\"=> "%2F",
	":" => "%3A",
	";" => "%3B",
	"<" => "%3C",
	"=" => "%3D",
	">" => "%3E",
	"?" => "%3F",
	"@" => "%40"
}

res = JSON.parse(Net::HTTP.get(URI("https://api.telegram.org/bot#{$api_key}/getUpdates")))
if res["ok"] == true
	puts "200 OK"
elsif res["ok"] == false
	puts "Error #{res["error_code"]}: #{res["description"]}\nPress ENTER to leave."
	gets
	abort
else
	puts "Undefined error.\nPress ENTER to leave."
	gets
	abort
end

puts Net::HTTP.get(URI("https://api.telegram.org/bot#{$api_key}/sendMessage?chat_id=#{$main_chat_id}&text=Erfolgreich mit Skript synchronisiert."))

$uids = []
$lmid = 0

ircBot = Cinch::Bot.new do
	configure do |c|
		c.nick = "sessho"
		c.user = "sessho"
		c.server = "irc.moep.net"
		c.channels = [] << "#klartraum"
	end
	
	on :message do |m|
		message = m.params[1]
		escapes.each do |chr, esc|
			begin
				message.gsub!(chr, esc)
			rescue
			end
		end
		debug "Message is now: #{message}"
		puts Net::HTTP.get(URI("https://api.telegram.org/bot#{$api_key}/sendMessage?chat_id=#{$main_chat_id}&text=#{m.user.nick}: #{message}"))
	end
end

threads = [] << Thread.new {
loop do
	ircBot.debug("Entering loop")
	res = JSON.parse(Net::HTTP.get(URI("https://api.telegram.org/bot#{$api_key}/getUpdates")))
	ircBot.debug("Successfully parsed JSON")
	$lmid = 0
	File.open("../kt_irc_bot_data/lmid.txt","r").each_line do |l|
		if l.chomp != ""
			$lmid = l.chomp.to_i
		end
	end
	ircBot.debug("Successfully read file, lMId is now #{$lmid}")
	if res["result"] != []
		ircBot.debug("result is not empty.")
		#++++++MAIN SENDER++++++
		res["result"].each do |i|
			if $lmid < i["message"]["message_id"].to_i
				ircBot.Channel("#klartraum").send("#{i["message"]["text"]}")
			end
		end
		#++++END MAIN SENDER++++
		ircBot.debug("Successfully sent message")
		res["result"].each do |i|
			$lmid = i["message"]["message_id"].to_i #Update lMId
		end
		ircBot.debug("Successfully updated lMId")
	else
		ircBot.debug("result is empty.")
	end
	
	File.open("../kt_irc_bot_data/lmid.txt","w") do |f|
		f.puts("#{$lmid}")
	ircBot.debug("Successfully wrote to file")
	end
	sleep 2
end
}

ircBot.start
