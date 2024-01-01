require "sinatra"
require "sinatra/reloader"
require "http"
require "sinatra/cookies"

get("/") do
  "
  <h1>Welcome to your Sinatra App!</h1>
  <p>Define some routes in app.rb</p>
  "
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

  cookies["last_location"]=@user_location
  cookies["last_lat"]=@latitude
  cookies["last_lng"]=@longitude

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
