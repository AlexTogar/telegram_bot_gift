module Translation
  require 'nokogiri'
  require 'net/http'
  require 'open-uri'
  require 'uri'
  require 'json'

  class Translate
    attr_accessor :input, :yandex_key

    def initialize(key: 'trnsl.1.1.20181019T100255Z.a1f5945c9e725938.33d1d873f6a0cb522f363ba06133bf8f0c32e678', input: '2+2')
      @yandex_key = key
      @input = input
    end

    def translate_static
      @input = URI.encode(@input)
      url = "https://translate.yandex.net/api/v1.5/tr.json/translate?key=#{@yandex_key}&text=#{@input}&lang=en-ru"
      response = Net::HTTP.get_response(URI.parse(url))
      json_response = JSON.parse(response.body)
      @input = json_response['text'][0]
    end

    def translate_neural
      # Инициализация результата
      text = "initial value"

      #заполнение констант
      uri = URI.parse("https://translate.api.cloud.yandex.net/translate/v2/translate")
      iam_token = ENV["IAM_TOKEN"]
      folder_id = ENV["FOLDER_ID"]

      header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{iam_token}"}
      data = {folder_id: "#{folder_id}",texts:["#{@input}"],targetLanguageCode:"ru"}

      # Создание запроса
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = data.to_json
      http.use_ssl = true

      # Отправка запроса
      response = http.request(request)

      #проверка на успешность запроса
      if response.kind_of? Net::HTTPSuccess
          json_str = response.body #string
      else
          # Обновление IAM_TOKEN

    
          # Создание нового запроса с одновленным IAM_TOKEN
          header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{iam_token}"}
          data = {folder_id: "#{folder_id}",texts:["#{@input}"],targetLanguageCode:"ru"}
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri, header)
          request.body = data.to_json
          http.use_ssl = true
      
          # Отправка запроса
          response = http.request(request)
          json_str = response.body
      end

      # Перевод первой из отправленных строчек
      text = JSON.parse(json_str)["translations"][0]["text"]
      return text

    end
  end
  end