# you need to install:
# -> gem install activesupport
# -> gem install nokogiri
# -> gem install unicode
require 'active_support/all'
require 'date'
require 'open-uri'
require 'unicode'
require 'rexml/document'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'telegram/bot'


token = ENV["bubu_token"]
alex_chat_id = 479_039_553

    # Telegram::Bot::Client.run(token) do |bot|
    #     bot.listen do |message|
    #         chat_id = message.chat.id

    #         # if message.text == "/schedule" then
    #         #     bot.api.send_message(chat_id: chat_id, text: "расписание))")
    #         # end
    #         bot.api.send_message(chat_id: chat_id, text: "ПрИвЕтиКи, я пока нипанимаю нисево, но туть скоро буит мб расписание0)0Буб")
    #     end
    # end

# loop do

    Telegram::Bot::Client.run(token) do |bot|
        bot.api.send_message(chat_id: alex_chat_id, text: "привет, сейчас: #{Time.now}")
    end

    # sleep(10)

# end