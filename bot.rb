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
#require_relative 'Translation'

# Объект для перевода через Yandex translator
#translation = Translation::Translate.new
token = ENV['bubu_token']
alex_chat_id = 479_039_553

# Подключение к redis
uri = URI.parse(ENV['REDISTOGO_URL'])
REDIS = Redis.new(host: uri.host, port: uri.port, password: uri.password)

# Прослушивание всех обращений
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
      # спросить 5 случайных фраз из списка
      when '/ask'
        all_phrases = REDIS.lrange("list:#{chat_id}")
        ask_message = ''
        all_phrases.sample(5).each do |phrase|
          eng_part = phrase.split('-')[0]
          ask_message += "#{end_part}\n"
          answer_message += phrase
        end
        bot.api.send_message(chat_id: chat_id, text: ask_message)
        REDIS.set("status:#{chat_id}", '2')
        REDIS.set("variables:#{chat_id}:answer", answer_message)
      # очистить список
      when '/clear'
        message_for_save = REDIS.lrange("list:#{chat_id}").join("\n")
        bot.api.send_message(chat_id: chat_id, text: message_for_save)
        REDIS.del("list:#{chat_id}")
      # обновить список
      when '/update'
        bot.api.send_message(chat_id: chat_id, text: 'write your new list down below')
        REDIS.set("status:#{chat_id}", '3')
      # вывести список
      when '/list'
        list_message = REDIS.lrange("list:#{chat_id}").join("\n")
        bot.api.send_message(chat_id: chat_id, text: list_message)
      # фраза с переводом
      when /[\w\,\?\!\.\ ]{1,}-[\w\,\?\!\.\ ]{1,}/
        REDIS.set("list:#{chat_id}", message.text)
        bot.api.send_message(chat_id: chat_id, text: 'added')
      # запрет на обработку start как слова для перевода
      when '/start'
        bot.api.send_message(chat_id: chat_id, text: "i'm ready to work")
      else
        #translation.input = message.text
        #response = translation.translate
        response = "alal"
        bot.api.send_message(chat_id: chat_id, text: "#{response} - add it into list?")
        REDIS.set("status:#{chat_id}", '1')
        REDIS.set("variables:#{chat_id}:current_response", response)
      end
    # status 1 - ожидание ответа 'Yes' или 'No' для сохранения или удаления фразы
    when '1'
      case message.text.downcase
      when 'yes'
        REDIS.lpush("list:#{chat_id}", REDIS.get("variables:#{chat_id}:curret_response"))
        bot.api.send_message(chat_id: chat_id, text: 'added')
        REDIS.set("status:#{chat_id}", '0')
      when 'no'
        bot.api.send_message(chat_id: chat_id, text: 'forgotten')
        REDIS.set("status:#{chat_id}", '0')
      else
        bot.api.send_message(chat_id: chat_id, text: "idk what you want, write 'yes' or 'no'")
      end
    # status 2 - ожидание ответа 'answer' для вывода ответа на заданные вопросы
    when '2'
      case message.text.downcase
      when 'answer'
        bot.api.send_message(chat_id: chat_id, text: REDIS.get("variables:#{chat_id}:answer"))
        REDIS.set("status:#{chat_id}", '0')
      else
        bot.api.send_message(chat_id: chat_id, text: "idk what you want (write 'answer')")
      end
    # status 3 - ожидание списка слов с переводом для заполнения листа сначала
    when '3'
      update_list = REDIS.get("variables:#{chat_id}:update_list").split("\n")
      update_list.each do |phrase|
        REDIS.lpush("list:#{chat_id}", phrase)
      end
      bot.api.send_message(chat_id: chat_id, text: 'list updated')
      REDIS.set("status:#{chat_id}", '0')
    # если в хранилище нет ключа status
    when nil
      REDIS.set("status:#{chat_id}", '0')
    end
  end
end
