# you need to install:
# -> gem install activesupport
# -> gem install nokogiri
# -> gem install unicode
require 'active_support/all'
require 'date'
require 'uri'
require 'open-uri'
require 'unicode'
require 'rexml/document'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'telegram/bot'
require 'redis'

token = ENV["bubu_token"]
alex_chat_id = 479_039_553
tanya_chat_id = 223_795_744
# Обязательное и не обязательное
categories = {:mandatory => 0, :optional => 0}

# Подключение к redis
uri =  URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    #Прослушивание всех обращений
    Telegram::Bot::Client.run(token) do |bot|
        bot.listen do |message|
            #Получение чата
            chat_id = message.chat.id
            #Обработка обращения от Тани
            if chat_id == alex_chat_id then
                #Список команд
                case message.text
                when "/начать"
                    if REDIS.GET("started").to_i == 0 then
                        REDIS.set("started", 1)
                        bot.api.send_message(chat_id: chat_id, text: "Начнем! укажи текущие значения денежных сумм на обязательные (x) и не обязательные вещи (y) c помощью команды /обновить x y")
                        bot.api.send_message(chat_id: chat_id, text: "Кроме этого ты можешь добавлять и отнимать суммы из выбранной катеогории с помощью команд ")
                    else
                        bot.api.send_message(chat_id: chat_id, text: "Работа уже начата! Ты можешь указать текущие значения денежных сумм для каждой категории с помощью соответствующих команд")
                    end
                when "/очистить"
                when /обновить [0-9]* [0-9]*/
                    
                    mandatory = message.text.split(" ")[1].to_i
                    optional = message.text.split(" ")[2].to_i
                    #Добавление элемета в лист состояний (обязательное - не обязательное - дата)
                    REDIS.rpush("state_list", "#{mandatory} #{optional} #{Date.today.strftime("%d-%m-%y")}")
                    REDIS.set("mandatory", mandatory)
                    REDIS.set("optional", optional)
                when /о +- надо как-то решить [0-9]*/
                    
                when /н +- надо как-то решить [0-9]*/
                
                when "/напомнить команды"
                    bot.api.send_message(chat_id: chat_id, text: "обновить x y - обновить значения суммы на обязательные траты (х) и на не обязательные траты (у)\n")
                else
                    bot.api.send_message(chat_id: chat_id, text: "Не понятно, проверь запрос, в нем что-то не так")
                end
            else
                #Обработка обращения посторонних людей
                first_name = message.forward_from.first_name
                last_name = message.forward_from.last_name
                bot.api.send_message(
                    chat_id: alex_chat_id, 
                    text: "Пользователь #{first_name} #{last_name}, chat_id: #{message.chat.id} написал боту Bubu: #{message.text}"
                    Redis.incr("messages_from_unknown")
                )
            end
        end
    end