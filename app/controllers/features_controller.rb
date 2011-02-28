class FeaturesController < ApplicationController
  before_filter :find_all_features
  before_filter :find_page

  def index
    @features      = @features.with_distance_to user_latlong if user_geolocated?
    @features_json = Feature.limit(9).map{|f| {:lat => f.lat, :lon => f.lon, :title => f.title, :id => f.id, :type => f.type} }.to_json.html_safe
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
    @feature_type   = @feature.type
    @random_feature = Feature.random_one_distinct_from @feature
    @nearest_places = Feature.with_distance_to(location_point).close_to(@feature.the_geom).where('id != ?', @feature.id).limit(3)

    itinerary       = @feature.itinerary_time_to location_point
    @itinerary_time = itinerary[:time]
    @itinerary_type = itinerary[:type]

    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    present(@page)
  end

  ## REMOVE ME

  def flickr_picker
    unless params[:id]
      query = "select features.* from features where gallery_id is null or gallery_id not in (select gallery_id from gallery_entries group by gallery_entries.gallery_id) order by features.id"
      @features = Feature.find_by_sql(query)
      return
    else
      @feature = Feature.find(params[:id])
      if @feature.gallery_id.blank?
        gallery = Gallery.create :name => @feature.title.truncate(255)
        @feature.update_attribute(:gallery_id, gallery.id)
      end
      params[:image_url].each do |flickr_url|
        next if flickr_url.blank?
        begin
          flickr_id = flickr_url.match(/\/(\d+)\//).captures[0]
          info = flickr.photos.getInfo :photo_id => flickr_id
          owner_name = info.owner['realname'] || info.owner['username']
          sizes = flickr.photos.getSizes :photo_id => flickr_id
          photo_url = sizes.find {|s| s.label == 'Large' || s.label == 'Original'}['source']
          owner_url = info.urls.first['_content'].split('/')[0..-2].join('/')
          response = Net::HTTP.get_response(URI.parse(photo_url))
          image = Image.create! :image => response.body, :author => owner_name, :author_url => owner_url, :source => "flickr"
          @feature.gallery.gallery_entries.create! :name => "Image for gallery #{@feature.gallery.name} ##{flickr_id}", :image_id => image.id
        rescue
          puts "================"
          puts "Error importing #{flickr_url}"
          puts "================"
        end
        flash[:feature_id] = feature_path(@feature.id)
      end
      redirect_to flickr_picker_path
    end
  end

protected

  def find_all_features
    if params && params[:q].present?
      @features = Feature.search(params[:q])
    else
      @features = Feature.scoped
    end

    # Search features by specified type
    @features = @features.send(params[:type]) if valid_type?

    # Search features by specified criteria
    @features = @features.by_criteria(params[:criteria]) if valid_criteria?

    @features = @features.page current_page
  end

  def find_page
    @page = Page.find_by_link_url("/features")
  end

  def valid_type?
    params && params[:type] && %w(cultural natural).include?(params[:type])
  end

  def valid_criteria?
    params && params[:criteria] && %w(i ii iii iv v vi vii viii ix x).include?(params[:criteria])
  end

  def current_page
    params[:page] || 1
  end
end
