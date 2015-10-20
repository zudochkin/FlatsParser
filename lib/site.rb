require 'curb'
require_relative '../mongo_client'

class Site
  attr_reader :urls_to_flats

  def initialize(url)
    @url = url
    @next_page = 0
    @urls_to_flats = []

    parse_all_pages
  end

  private

  def parse_all_pages
    while(row = next_url_row) do
      @urls_to_flats.concat row[:urls_to_flats]
    end
  end

  def next_url_row
    @next_page += 1

    if $mongo_client[:pages].find(url: next_url).first.nil?
      content = curl

      return nil unless content

      doc = Nokogiri::HTML(content)

      urls = doc.css('h3.title > a').map { |e| normalize_url(e[:href]) }

      $mongo_client[:pages].insert_one(url: next_url, content: content, urls_to_flats: urls)
    end

    $mongo_client[:pages].find(url: next_url).first
  end

  def curl
    curl = Curl.get(next_url)

    if curl.status.to_i == 200
      curl.body.force_encoding('utf-8')
    end
  end

  def next_url
    "#{@url}&p=%d" % @next_page
  end

  def normalize_url(url)
    if url[/http/]
      url
    else
      "https://www.avito.ru#{url}"
    end
  end
end