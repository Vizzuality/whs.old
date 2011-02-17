class HomeController < ApplicationController

  before_filter :find_all_features

  def show
    @closests_features = nil
    @user_city         = user_city
    @user_latlong      = user_latlong

    if user_geolocated?
      @features          = @features.with_distance_to(user_latlong)
      user_latlong       = Point.from_x_y(session[:user_location][:lon], session[:user_location][:lat])
      @closests_features = Feature.with_distance_to(user_latlong).close_to(user_latlong).limit(9)
    end

    render :action=>"show",:layout=>"home_layout"
  end

protected

  def find_all_features
    @features = Feature.random.limit(9)
  end


end
