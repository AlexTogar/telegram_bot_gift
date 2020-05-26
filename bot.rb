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
require_relative 'Translation'

translation = Translation::Translate.new
token = ENV["bubu_token"]
alex_chat_id = 479039553

# Подключение к redis
uri =  URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    #Прослушивание всех обращений
    Telegram::Bot::Client.run(token) do |bot|
        bot.listen do |message|
          # Получение чата
          chat_id = message.chat.id
          # Обработка обращения
          case REDIS.get("status:#{chat_id}")
          # status 0 - обычная работа
          when '0'
            # Список команд
            case message.text.downcase
            when '/flushall'
              REDIS.flushall
              REDIS.set("status:#{chat_id}", '0')
            # спросить 5 случайных фраз из списка
            when /(\/ask)/
              #direction = 0 или 1 с равной вероятностью - определят язык вопроса
              direction = rand.round
              all_phrases = REDIS.lrange("list:#{chat_id}", 0, -1)
              ask_message = ''
              answer_message = ''
              all_phrases.sample(5).each do |phrase|
                eng_part, rus_part = phrase.split('-')[0], phrase.split('-')[1]
                direction == 0? ask_message += "#{eng_part}\n" : ask_message += "#{rus_part}\n"
                answer_message += "#{phrase}\n"
              end
              
              bot.api.send_message(chat_id: chat_id, text: ask_message)
              REDIS.set("status:#{chat_id}", '2')
              REDIS.set("variables:#{chat_id}:answer", answer_message)
            # очистить список
            when /(\/clear)/
              # вывод всего списка перед удалением
              list_message = REDIS.lrange("list:#{chat_id}", 0, -1).join("\n")
              #если сообщение слишком длинное (максимум - 4096)
              if list_message.size > 4000
                list_message_array = list_message.split("\n")
                phrases_num = 50
                message_num = (list_message_array.size/phrases_num).to_i + 1
                for i in (1..message_num) do
                  message = list_message_array[(i-1)*phrases_num..i*phrases_num-1].join("\n")
                  if message != nil and message != '' then
                    bot.api.send_message(chat_id: chat_id, text: message)
                  else
                    bot.api.send_message(chat_id: chat_id, text: "error")
                  end
                end
              else
                if list_message != nil and list_message != '' then
                  bot.api.send_message(chat_id: chat_id, text: list_message)
                else
                  bot.api.send_message(chat_id: chat_id, text: "list is empty")
                end
              end
              #конец вывода списка перед удалением
              REDIS.del("list:#{chat_id}")
            # обновить список
            when /(\/update)/
              bot.api.send_message(chat_id: chat_id, text: "write your new list down below (or send 'no')\nformat:<eng part> - <rus part>")
              REDIS.set("status:#{chat_id}", '3')
            # вывести список
            when /(\/list)/
              list_message = REDIS.lrange("list:#{chat_id}", 0, -1).join("\n")
              #если сообщение слишком длинное (максимум - 4096)
              if list_message.size > 4000
                list_message_array = list_message.split("\n")
                phrases_num = 50
                message_num = (list_message_array.size/phrases_num).to_i + 1
                for i in (1..message_num) do
                  message = list_message_array[(i-1)*phrases_num..i*phrases_num-1].join("\n")
                  if message != nil and message != '' then
                    bot.api.send_message(chat_id: chat_id, text: message)
                  else
                    bot.api.send_message(chat_id: chat_id, text: "error")
                  end
                end
              else
                if list_message != nil and list_message != '' then
                  bot.api.send_message(chat_id: chat_id, text: list_message)
                else
                  bot.api.send_message(chat_id: chat_id, text: "list is empty")
                end
              end

            # фраза с переводом
            when /[\w\,\?\!\.\ ]{1,}-[\w\,\?\!\.\ ]{1,}/
              REDIS.lpush("list:#{chat_id}", message.text)
              bot.api.send_message(chat_id: chat_id, text: 'added')
            # отменить последнее добавление в список
            when /(\/revert)/
              removed_item = REDIS.lpop("list:#{chat_id}")
              bot.api.send_message(chat_id: chat_id, text: "last item has been removed: #{removed_item}")
            when /(\/answer)/
              bot.api.send_message(chat_id: chat_id, text: "first you have to write '/ask'")
            # запрет на обработку start как слова для перевода
            when /(\/start)/
              bot.api.send_message(chat_id: chat_id, text: "i'm ready to work")
            # фраза без перевода
            else
              translation.input = message.text
              list = REDIS.lrange("list:#{chat_id}", 0, -1).map{|str| [str.split(" - ")[0], str.split(" - ")[1]]}
              eng_part_list = list.map{|array| array[0]}
              #если запрашиваемое слово уже есть в списке, то сообщить это и дать перевод
              if eng_part_list.include? message.text
                #found_phrase имеет структуру ["phrase", "фраза"]
                found_phrase = list.select{|array| array[0] == message.text}[0]
                bot.api.send_message(chat_id: chat_id, text: "#{found_phrase[1]} - exists already")
              else
                #translate_static или translate_neural
                response = translation.translate_neural
                bot.api.send_message(chat_id: chat_id, text: "#{response} - add it into list?")
                REDIS.set("status:#{chat_id}", '1')
                #если переведенное выражение на английском (содрежит хотя бы один англ. символ)
                if /[a-zA-Z]+/.match(response)
                  REDIS.set("variables:#{chat_id}:current_response", "#{response} - #{message.text}")
                else
                  REDIS.set("variables:#{chat_id}:current_response", "#{message.text} - #{response}")
                end
              end
            end
          # status 1 - ожидание ответа 'Yes' или 'No' для сохранения или удаления фразы
          when '1'
            case message.text.downcase
            when /y|(yes)|(\/yes)/
              REDIS.lpush("list:#{chat_id}", REDIS.get("variables:#{chat_id}:current_response"))
              bot.api.send_message(chat_id: chat_id, text: 'added')
              REDIS.set("status:#{chat_id}", '0')
            when /n|(no)|(\/no)/
              bot.api.send_message(chat_id: chat_id, text: 'forgotten')
              REDIS.set("status:#{chat_id}", '0')
            else
              bot.api.send_message(chat_id: chat_id, text: "idk what you want, write 'yes' or 'no'")
            end
          # status 2 - ожидание ответа 'answer' для вывода ответа на заданные вопросы
          when '2'
            case message.text.downcase
            when /(\/answer)/
              bot.api.send_message(chat_id: chat_id, text: REDIS.get("variables:#{chat_id}:answer"))
              REDIS.set("status:#{chat_id}", '0')
            else
              bot.api.send_message(chat_id: chat_id, text: "idk what you want (write '/answer')")
            end
          # status 3 - ожидание списка слов с переводом для заполнения листа сначала
          when '3'
            if message.text != "no"
              update_list = message.text.split("\n")
              REDIS.del("list:#{chat_id}")
              REDIS.lpush("list:#{chat_id}", update_list)
              bot.api.send_message(chat_id: chat_id, text: 'list updated')
              REDIS.set("status:#{chat_id}", '0')
            else
              bot.api.send_message(chat_id: chat_id, text: 'operation interrupted')
              REDIS.set("status:#{chat_id}", '0')
            end
          # если в хранилище нет ключа status
          when nil
            REDIS.set("status:#{chat_id}", '0')
          end
        end
    end