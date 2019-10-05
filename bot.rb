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


token = "839130442:AAECf-LcETBUyNAy26jHmrt_BW_d5qUT938"
alex_chat_id = 479_039_553

    Telegram::Bot::Client.run(token) do |bot|
        bot.listen do |message|
            chat_id = message.chat.id

            if message.text == "/schedule" then
                bot.api.send_message(chat_id: chat_id, text: "расписание))")
            end
        end
    end