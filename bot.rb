# you need to install:
# -> gem install activesupport
# -> gem install nokogiri
# -> gem install unicode
# -> gem install redis
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
                when "/start"
                    if REDIS.GET("started").to_i == 0 then
                        REDIS.set("started", 1)
                        #установка категорий по умолчинаю и в 0
                        REDIS.set("mandatory", 0)
                        REDIS.set("optional", 0)
                        bot.api.send_message(chat_id: chat_id, text: "Начнем! укажи текущие значения денежных сумм на обязательные (x) и не обязательные вещи (y) c помощью команды 'обновить x y'")
                        bot.api.send_message(chat_id: chat_id, text: "Кроме этого ты можешь добавлять и отнимать суммы из выбранной катеогории с помощью команд типа 'o +5000' или 'н -1000' (что значит добавить к обязат. 5000 и отнять от необязат. 1000 соответственно) ")
                        bot.api.send_message(chat_id: chat_id, text: "Еще ты можешь обновить значения категорий отдельно с помощью команд типа 'обновить о 5000', что установит категории обязат. значение 5000")
                        bot.api.send_message(chat_id: chat_id, text: "Получить текущие значения денег ты можешь с помощью команды /show, установить значения в 0 ты можешь с помощью команды /clear (используй символ / на нижней панели чата со мной (ботом)")
                        bot.api.send_message(chat_id: chat_id, text: "Если ты хочешь, чтобы я напомнил команды, используй команду /info")
                    else
                        bot.api.send_message(chat_id: chat_id, text: "Работа уже начата! Ты можешь указать текущие значения денежных сумм для каждой категории с помощью соответствующих команд")
                    end
                    REDIS.rpush("state_list", "#{mandatory} #{optional} #{Date.today.strftime("%d-%m-%y")}")


                when "/clear"
                    REDIS.set("mandatory", 0)
                    REDIS.set("optional", 0)
                    bot.api.send_message(chat_id: chat_id, text: "Обе категории сброшены в 0, используйте /show, чтобы в этом убедиться")
                    REDIS.rpush("state_list", "#{mandatory} #{optional} #{Date.today.strftime("%d-%m-%y")}")

                when "/show"
                    bot.api.send_message(chat_id: chat_id, text: "о: #{REDIS.get("mandatory")}\nн: #{REDIS.get("optional")}")


                when "/info"
                    bot.api.send_message(chat_id: chat_id, text: "обновить 100 200 - обновить значения суммы на обязательные траты (100р) и на не обязательные траты (200р)\n\nобновить о 100 - обновить значение категории о на 100\n\nобновить н 200 - обновить значение категории н на 200\n\nо +5000 - увеличить значение категории о на 5000р (доход)\n\nн -200 - уменьшить значение категории н на 200 (трата)\n\nОписание остальных команд можно посмотреть при нажатии на символ '/' внизу чата со мной (ботом)")

                    
                when "/flushall"
                    REDIS.flushall

                #обновить 5000 3000 - пример команды
                when /обновить [0-9]{1,} [0-9]{1,}/
                    mandatory = message.text.split(" ")[1].to_i
                    optional = message.text.split(" ")[2].to_i
                    #Добавление элемета в лист состояний (обязательное - не обязательное - дата)
                    REDIS.set("mandatory", mandatory)
                    REDIS.set("optional", optional)
                    bot.api.send_message(chat_id: chat_id, text: "Значения обновлены")
                    REDIS.rpush("state_list", "#{mandatory} #{optional} #{Date.today.strftime("%d-%m-%y")}")


                #обновить о 5000 - пример команды
                when /обновить о [0-9]{1,}/
                    mandatory = message.text.split(" ")[2].to_i
                    REDIS.set("mandatory", mandatory)
                    bot.api.send_message(chat_id: chat_id, text: "о установлена в #{mandatory}")
                    REDIS.rpush("state_list", "#{REDIS.get("mandatory")} #{REDIS.get("optional")} #{Date.today.strftime("%d-%m-%y")}")


                #обновить н 3000 - пример команды
                when /обновить н [0-9]{1,}/
                    optional = message.text.split(" ")[2].to_i
                    REDIS.set("optional", optional)
                    bot.api.send_message(chat_id: chat_id, text: "н установлена в #{optional}")
                    REDIS.rpush("state_list", "#{REDIS.get("mandatory")} #{REDIS.get("optional")} #{Date.today.strftime("%d-%m-%y")}")


                #о +5000 - пример команды
                when /о [\+\-]{1}[0-9]{1,}/
                    delta_mandatory = message.text.split(" ")[1][1..-1].to_i
                    case message.text.split(" ")[1][0]
                    when "+"
                        REDIS.set("mandatory", REDIS.get("mandatory").to_i + delta_mandatory)
                        bot.api.send_message(chat_id: chat_id, text: "о увеличен на #{delta_mandatory}р")
                    when "-"
                        remains = REDIS.get("mandatory").to_i - delta_mandatory
                        if remains > 0 then
                            REDIS.set("mandatory", REDIS.get("mandatory").to_i - delta_mandatory)
                            bot.api.send_message(chat_id: chat_id, text: "о уменьшен на #{delta_mandatory}р")
                        else
                            bot.api.send_message(chat_id: chat_id, text: "у тебя не хватает #{remains.abs}р для совершения этой транзакции")
                        end
                    else
                        bot.api.send_message(chat_id: chat_id, text: "ошибка в запросе")
                    end
                    REDIS.rpush("state_list", "#{REDIS.get("mandatory")} #{REDIS.get("optional")} #{Date.today.strftime("%d-%m-%y")}")


                #н -3000 - пример команды
                when /н [\+\-]{1}[0-9]{1,}/
                    delta_optional = message.text.split(" ")[1][1..-1].to_i
                    case message.text.split(" ")[1][0]
                    when "+"
                        REDIS.set("optional", REDIS.get("optional").to_i + delta_optional)
                        bot.api.send_message(chat_id: chat_id, text: "н увеличен на #{delta_optional}р")
                    when "-"
                        remains = REDIS.get("optional").to_i - delta_optional
                        if remains > 0 then
                            REDIS.set("optional", REDIS.get("optional").to_i - delta_optional)
                            bot.api.send_message(chat_id: chat_id, text: "н уменьшен на #{delta_optional}р")
                        else
                            bot.api.send_message(chat_id: chat_id, text: "у тебя не хватает #{remains.abs}р для совершения этой транзакции")
                        end
                    else
                        bot.api.send_message(chat_id: chat_id, text: "ошибка в запросе")
                    end
                    REDIS.rpush("state_list", "#{REDIS.get("mandatory")} #{REDIS.get("optional")} #{Date.today.strftime("%d-%m-%y")}")


                else
                    bot.api.send_message(chat_id: chat_id, text: "Не понятно, проверь запрос, в нем что-то не так")
                end
            else
                #Обработка обращения посторонних людей
                first_name = message.forward_from.first_name
                last_name = message.forward_from.last_name
                bot.api.send_message(
                    chat_id: alex_chat_id, 
                    text: "Пользователь #{first_name} #{last_name}, chat_id: #{message.chat.id} написал боту Bubu: #{message.text}")
                    REDIS.incr("messages_from_unknown")
            end
        end
    end