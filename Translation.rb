module Translation
  require 'nokogiri'
  require 'net/http'
  require 'open-uri'
  require 'uri'
  require 'json'

  class Translate
    attr_accessor :input, :yandex_key, :iam_token, :folder_id

    def initialize(key: 'trnsl.1.1.20181019T100255Z.a1f5945c9e725938.33d1d873f6a0cb522f363ba06133bf8f0c32e678', input: '2+2', iam_token: ENV["IAM_TOKEN"], folder_id: ENV["FOLDER_ID"])
      @yandex_key = key
      @input = input
      @iam_token = iam_token
      @folder_id = folder_id
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
      json_str = "initial value"
      targetLanguageCode = "ru"
      #если в input содержит хотя бы один русский символ, поменять язык перевода на английский
      if /[а-яА-Я]+/.match(@input)
        targetLanguageCode = "en"
      end
      #заполнение констант
      uri = URI.parse("https://translate.api.cloud.yandex.net/translate/v2/translate")

      header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{@iam_token}"}
      data = {folder_id: "#{@folder_id}",texts:["#{@input}"],targetLanguageCode:targetLanguageCode}

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
          # Обновление IAM_TOKEN и сохранение в переменную окружения
          new_iam_token = get_new_iam_token
          ENV["IAM_TOKEN"] = new_iam_token
          @iam_token = new_iam_token

          # Создание нового запроса с одновленным IAM_TOKEN
          header = {'Content-Type': 'application/json', 'Authorization': "Bearer #{@iam_token}"}
          data = {folder_id: "#{@folder_id}",texts:["#{@input}"],targetLanguageCode:"ru"}
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Post.new(uri.request_uri, header)
          request.body = data.to_json
          http.use_ssl = true
      
          # Отправка запроса
          response = http.request(request)
          if response.kind_of? Net::HTTPSuccess
            json_str = response.body
          else
            puts 'error after iam updating'
          end
      end

      # Перевод первой из отправленных строчек
      text = JSON.parse(json_str)["translations"][0]["text"]
      return text

    end
  end
  end

  def get_new_iam_token
    #curl -d "{\"yandexPassportOauthToken\":\"<OAuth-token>\"}" "https://iam.api.cloud.yandex.net/iam/v1/tokens"
    uri = URI.parse("https://iam.api.cloud.yandex.net/iam/v1/tokens")
    data = {yandexPassportOauthToken: ENV["OAUTH_TOKEN"]}
    data = {yandexPassportOauthToken: "AgAAAAAdTi3LAATuwYoimoAMMEd4pM-DHZFe9GA"}

    # Создание запроса
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = data.to_json
    http.use_ssl = true

    # Отправка запроса
    response = http.request(request)
    new_token = JSON.parse(response.body)["iamToken"]
    return new_token
  end


  