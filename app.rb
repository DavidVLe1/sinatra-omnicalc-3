require "sinatra"
require "sinatra/reloader"
require "http"
require "sinatra/cookies"

get("/") do
  redirect "/umbrella"
end

get("/umbrella") do
  erb(:umbrella_form)
end

post("/process_umbrella") do
  @user_location = params.fetch("user_loc")
  gmaps_api_key = ENV.fetch("GMAPS_KEY")

  url_encoded_string = @user_location.gsub(" ", "+")

  gmaps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{url_encoded_string}&key=" + gmaps_api_key

  @raw_response = HTTP.get(gmaps_url).to_s
  @parsed_response = JSON.parse(@raw_response)

  @loc_hash = @parsed_response.dig("results", 0, "geometry", "location")
  @latitude = @loc_hash.fetch("lat")
  @longitude = @loc_hash.fetch("lng")

  cookies["last_location"] = @user_location
  cookies["last_lat"] = @latitude
  cookies["last_lng"] = @longitude

  pirate_weather_api_key = ENV.fetch("PIRATE_WEATHER_KEY")

  pirate_weather_url = "https://api.pirateweather.net/forecast/" + pirate_weather_api_key + "/" + @latitude.to_s + "," + @longitude.to_s
  @raw_weather_response = HTTP.get(pirate_weather_url).to_s
  @parsed_weather_response = JSON.parse(@raw_weather_response)

  @currently_hashed = @parsed_weather_response.fetch("currently")
  @current_temp = @currently_hashed.fetch("temperature")

  @summary = @currently_hashed.fetch("summary")

  precipitation = @currently_hashed.fetch("precipProbability")
  @umbrella_needed = "You probably won't need an umbrella."
  if precipitation > 0
    @umbrella_needed = "You probably will need an umbrella."
  end
  erb(:umbrella_results)
end

get("/message") do
  erb(:message_form)
end

post("/process_single_message") do
  request_headers_hash = {
    "Authorization" => "Bearer #{ENV.fetch("OPEN_AI_KEY")}",
    "content-type" => "application/json",
  }

  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {
        "role" => "system",
        "content" => "You are a helpful assistant who talks like Shakespeare.",
      },
      {
        "role" => "user",
        "content" => "#{params.fetch("the_message")}",
      },
    ],
  }

  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json,
  ).to_s

  @parsed_response = JSON.parse(raw_response)

  @reply = @parsed_response.dig("choices", 0, "message", "content")
  @formatted_reply = @reply.gsub("\n", "<br>")
  cookies["input"] = params.fetch("the_message")

  erb(:message_results)
end

get("/chat") do
  erb(:chat_form)
end

post("/clear_chat") do
  cookies[:chat_history]=JSON.generate([])
  redirect "/chat"
end

post("/add_message_to_chat") do
  @chat_history = JSON.parse(cookies[:chat_history] || "[]")
  @current_message = params.fetch("user_message")
  @chat_history << { "role" => "user", "content" => @current_message }
  request_headers_hash = {
    "Authorization" => "Bearer #{ENV.fetch("OPEN_AI_KEY")}",
    "content-type" => "application/json"
  }

  req_msg = [
    {
      "role" => "system",
      "content" => "You can only respond like Mario from Mario and Luigi."
    },
    {
      "role" => "user",
      "content" => @current_message
    }
  ]

  @chat_history.each do |msg|
    req_msg << {
      "role" => msg["role"],
      "content" => msg["content"]
    }
  end
  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => req_msg
  }
  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json
  ).to_s

  @parsed_response = JSON.parse(raw_response)
  @reply = @parsed_response.dig("choices", 0, "message", "content")
  @chat_history << { "role" => "assistant", "content" => @reply }
  cookies[:chat_history] = JSON.generate(@chat_history)

  erb(:chat_form)
end
