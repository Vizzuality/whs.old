module FeatureExtensions
  extend ActiveSupport::Concern

  included  do
    class_eval do
      paginates_per 9

      attr_writer :lat, :lng

      # Returns all features without consolidated images
      scope :without_consolidated_images, where('meta not like ?', "%:images_consolidated: true%")

      # Returns all features with consolidated images
      scope :with_consolidated_images, where('meta like ?', "%:images_consolidated: true%")

      # Returns all features with a gallery associated
      scope :with_gallery, where('gallery_id IS NOT NULL')

      # Adds a field 'distance' with the calculated distance from feature to specified point
      scope :with_distance_to, lambda{|point| select("#{custom_fields.join(', ')}, ST_Distance(the_geom::geography, GeomFromText('POINT(#{point.x} #{point.y})', 4326)) as distance") }

      # Returns features ordered by closest to specified point
      scope :close_to, lambda{|point| order("ST_Distance(the_geom::geography, GeomFromText('POINT(#{point.x} #{point.y})', 4326))") }

      # Orders features randomly
      scope :random, order("RANDOM()")

      # Adds the geom to the list of selected fields (removed by default to improve performance)
      scope :with_the_geom, select('the_geom')

      # Gets all natural features
      scope :natural, where('meta like ?', "%:type: natural%")

      # Gets all cultural features
      scope :cultural, where('meta like ?', "%:type: cultural%")

      # Filters query by feature criteria
      scope :by_criteria, lambda{|criteria| where('meta like ?', "%#{criteria}%") }

      # Filter query search matches in description or meta fields
      scope :search, lambda{|q| where('description like ? OR meta like ?', "%#{q}%", "%#{q}%")}

    end
  end

  module ClassMethods

    # By default, removes 'the_geom' from the default select columns
    def custom_fields
      lat_long       = ['ST_Y(the_geom) as lat', 'ST_X(the_geom) as lon']
      (columns.map{ |c| c.name } - ['the_geom']).map{ |c| "#{self.table_name}.#{c}" } + lat_long
    end

    # Returns all heritage sites with the specified whs site id (must be only one ALWAYS)
    def by_whs_site_id(id)
      scoped.where('meta like ?', "%:whs_site_id: \"#{id}\"%").limit(1).first
    end

    # Gets the next feature's images without consolidated images
    def feature_images(feature_id = nil)
      feature = if feature_id
        Feature.with_gallery.by_whs_site_id(feature_id)
      else
        self.with_gallery.without_consolidated_images.sample
      end

      return nil if feature.nil?

      result = nil
      if feature

        images = feature.gallery.gallery_entries.select{|g| g.image }

        if images.present?
          result = {
            :feature_id => feature.whs_site_id,
            :name => feature.title,
            :pics => images.map{|gallery| {:pic_id => gallery.id, :url_big => gallery.image.thumbnail(:large).url, :url_small => gallery.image.thumbnail(:small).url}}
          }
        end
      end
      result
    end

    # Gets a randome feature from database, distinct from the one specified
    def random_one_distinct_from(feature)
      scoped.random.limit(1).where('id != ?', feature.id).first
    end
  end

  module InstanceMethods
    def consolidate_images(pics_ids)
      pics_ids = pics_ids.split(',').map{|id| id.to_i}
      images = []
      pics_ids.each do |pic_id|
        images << [GalleryEntry.find(pic_id).name, GalleryEntry.find(pic_id).image]
      end

      gallery.gallery_entry_ids = nil
      images.each do |image|
        gallery.gallery_entries.create! :name => image.first, :image_id => image.last.id
      end
      meta[:images_consolidated] = true
      save!
    end

    def distance_to point
      distance = 0
      results = Feature.select("ST_Distance(the_geom::geography, GeomFromText('POINT(#{point.x} #{point.y})', 4326)) as distance").where(:id => self.id).first
      distance = results.distance if results
      distance.to_i
    end

    def itinerary_time_to(location)
      itinerary = {:time => '0 hours'}
      itinerary = calculate_itinerary distance_to location if location.present?
      itinerary
    end

    def distance_in_time
      calculate_itinerary(distance.to_f) if distance?
    end

    def calculate_itinerary(distance)
      itinerary = {}
      case
      # Distance is less than 500 meters, we're going by walking
      when distance < 500
        itinerary[:type] = 'walking'
        itinerary[:time] = (distance * 1.10 / 5_000).hours.ago
      # Distance is between 500 meters and 800 kilometers, we're going by car
      when distance >= 500 && distance < 800_000
        itinerary[:type] = 'car'
        itinerary[:time] = (distance * 1.30 / 120_000).hours.ago
      # Distance is greater than 800 kilometers, we're going by plane
      when distance >= 800_000
        itinerary[:type] = 'plane'
        itinerary[:time] = (distance / 700_000).hours.ago
      end
      itinerary
    end
    private :calculate_itinerary

    # Query google directions to obtain itinerary from location to the feature
    def query_google_directions(location, mode = 'driving')
      require 'net/http'
      origin = "#{the_geom.y},#{the_geom.x}"
      destination = "#{location.y},#{location.x}"
      url = "http://maps.google.com/maps/api/directions/json?mode=#{mode}&origin=#{origin}&destination=#{destination}&sensor=false".gsub(" ", "+")
      response = Net::HTTP.get(::URI.parse(url))
      directions = JSON.parse(response) if response
      directions
    end
    private :query_google_directions

  end

  def lat
    self.the_geom? && self.the_geom.y ? self.the_geom.y : @lat
  end

  def lon
    self.the_geom? && self.the_geom.x ? self.the_geom.x : @lon
  end

  def to_json
    super(:methods => [:lat, :lon])
  end

end

require 'feature.rb'
Feature.send :include, FeatureExtensions
