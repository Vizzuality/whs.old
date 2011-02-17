class FeaturesController < ApplicationController
  before_filter :find_all_features
  before_filter :find_page

  def index
    @features      = @features.with_distance_to user_latlong if user_geolocated?
    @features_json = @features.map{|f| {:lat => f.lat, :lon => f.lon, :title => f.title, :id => f.id, :type => f.type} }.to_json.html_safe
    @user_city     = user_city

    if request.xhr?
      render :partial => 'features'
    else
      present(@page)
    end
  end

  def show
    location_point  = user_geolocated?? user_latlong : @feature.the_geom
    @user_city      = user_city

    @feature        = Feature.find(params[:id])
    @random_feature = Feature.random_one_distinct_from @feature
    @nearest_places = Feature.with_distance_to(location_point).close_to(@feature.the_geom).limit(3)

    itinerary       = @feature.itinerary_time_to location_point
    @itinerary_time = itinerary[:time]
    @itinerary_type = itinerary[:type]

    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    present(@page)
  end

protected

  def find_all_features
    if params && params[:q].present?
      @features = Feature.search(params[:q]).limit(9)
    else
      @features = Feature.limit(9)
    end

    # Search features by specified type
    @features = @features.send(params[:type]) if params && params[:type] && %w(cultural natural).include?(params[:type])
  end

  def find_page
    @page = Page.find_by_link_url("/features")
  end

end
