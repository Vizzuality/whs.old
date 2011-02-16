class FeaturesController < ApplicationController
  before_filter :find_all_features
  before_filter :find_page

  def index
    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    @random_features = @features.sample(9)
    present(@page)
  end

  def show
    @feature        = Feature.find(params[:id])
    @random_feature = Feature.all.reject{|f| f.id == @features.id}.sample
    @user_location  = ''
    if session[:user_location] && session[:user_location][:lon] && session[:user_location][:lat]
      location_point = Point.from_x_y(session[:user_location][:lon], session[:user_location][:lat])
      @user_location  = session[:user_location][:city] if session[:user_location][:city]
    else
      location_point = @feature.the_geom
    end

    @nearest_places = Feature.close_to(location_point).first(3)

    itinerary       = @feature.calculate_itinerary_time_to location_point
    @itinerary_time = itinerary[:time]
    @itinerary_type = itinerary[:type]


    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    present(@page)
  end

protected

  def find_all_features
    @features = Feature.find(:all, :order => "position ASC")
  end

  def find_page
    @page = Page.find_by_link_url("/features")
  end

end
