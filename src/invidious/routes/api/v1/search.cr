module Invidious::Routes::API::V1::Search
  def self.search(env)
    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?
    extend_desc = env.params.query["extend_desc"]? == "true"

    env.response.content_type = "application/json"

    query = Invidious::Search::Query.new(env.params.query, :regular, region)

    begin
      search_results = query.process
    rescue ex
      return error_json(400, ex)
    end

    # If extend_desc is requested, fetch full descriptions for video results
    if extend_desc
      search_results = search_results.map do |item|
        if item.is_a?(SearchVideo)
          extend_video_description(item, locale)
        else
          item
        end
      end
    end

    JSON.build do |json|
      json.array do
        search_results.each do |item|
          item.to_json(locale, json)
        end
      end
    end
  end

  def self.search_suggestions(env)
    preferences = env.get("preferences").as(Preferences)
    region = env.params.query["region"]? || preferences.region

    env.response.content_type = "application/json"

    query = env.params.query["q"]? || ""

    begin
      client = make_client(URI.parse("https://suggestqueries-clients6.youtube.com"), force_youtube_headers: true)
      url = "/complete/search?client=youtube&hl=en&gl=#{region}&q=#{URI.encode_www_form(query)}&gs_ri=youtube&ds=yt"

      response = client.get(url).body
      client.close

      body = JSON.parse(response[19..-2]).as_a
      suggestions = body[1].as_a[0..-2]

      JSON.build do |json|
        json.object do
          json.field "query", body[0].as_s
          json.field "suggestions" do
            json.array do
              suggestions.each do |suggestion|
                json.string suggestion[0].as_s
              end
            end
          end
        end
      end
    rescue ex
      return error_json(500, ex)
    end
  end

  def self.hashtag(env)
    hashtag = env.params.url["hashtag"]

    page = env.params.query["page"]?.try &.to_i? || 1

    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?
    env.response.content_type = "application/json"

    begin
      results = Invidious::Hashtag.fetch(hashtag, page, region)
    rescue ex
      return error_json(400, ex)
    end

    JSON.build do |json|
      json.object do
        json.field "results" do
          json.array do
            results.each do |item|
              item.to_json(locale, json)
            end
          end
        end
      end
    end
  end

  # Helper method to fetch full description for a video from the video details API
  # This is needed because search results (compactVideoRenderer) don't include descriptions
  private def self.extend_video_description(video : SearchVideo, locale : String?) : SearchVideo
    begin
      # Fetch video details to get the full description
      video_details = get_video(video.id, region: nil)
      
      # Create a new SearchVideo with the extended description
      return SearchVideo.new({
        title:              video.title,
        id:                 video.id,
        author:             video.author,
        ucid:               video.ucid,
        published:          video.published,
        views:              video.views,
        description_html:   video_details.descriptionHtml || "",
        length_seconds:     video.length_seconds,
        premiere_timestamp: video.premiere_timestamp,
        author_verified:    video.author_verified,
        author_thumbnail:   video.author_thumbnail,
        badges:             video.badges,
      })
    rescue ex
      LOGGER.warn("Failed to fetch description for video #{video.id}: #{ex.message}")
      # Return original video if fetching fails
      return video
    end
  end
end
