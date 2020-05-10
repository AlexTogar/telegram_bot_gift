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

    def translate
      @input = URI.encode(@input)
      url = "https://translate.yandex.net/api/v1.5/tr.json/translate?key=#{@yandex_key}&text=#{@input}&lang=en-ru"
      response = Net::HTTP.get_response(URI.parse(url))
      json_response = JSON.parse(response.body)
      @input = json_response['text'][0]
    end
  end
  end
