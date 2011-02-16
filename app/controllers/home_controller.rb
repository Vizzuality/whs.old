class HomeController < ApplicationController

  before_filter :find_all_features

  def show
    @random_features   = @features.sample(9)
    @closests_features = @random_features
    @user_city         = user_city

    if user_geolocated?
      user_latlong       = Point.from_x_y(session[:user_location][:lon], session[:user_location][:lat])
      @closests_features = Feature.close_to(user_latlong).first(9).map{|f| [f, f.calculate_itinerary_time_to(user_latlong)]}
    end

    render :action=>"show",:layout=>"home_layout"
  end

protected

  def find_all_features
    @features = Feature.find(:all, :order => "position ASC")
  end


end
