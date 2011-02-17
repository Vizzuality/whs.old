module FeatureExtensions
  extend ActiveSupport::Concern

  included  do
    class_eval do
      include PgSearch
      pg_search_scope :search, :against => {
        :title => 'A',
        :meta => 'B',
        :description => 'C'
      }

      pg_search_scope :search_meta, :against => :meta

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
      scope :random, lambda{ |point| order("RANDOM()") }

      # Adds the geom to the list of selected fields (removed by default to improve performance)
      scope :with_the_geom, select('the_geom')

      # Filters query by feature type (cultural/natural)
      scope :with_type, lambda{|type| where('meta like ?', "%:type: #{type}%")}

      # Gets all natural features
      scope :natural, search_meta('type: natural')

      # Gets all cultural features
      scope :cultural, search_meta('type: cultural')
    end
  end

  module ClassMethods

    # By default, removes 'the_geom' from the default select columns
    def custom_fields
      lat_long       = ['ST_Y(the_geom) as lat', 'ST_X(the_geom) as lon']
      pg_search_rank = ["(ts_rank((setweight(to_tsvector( coalesce(\"features\".\"meta\", '')), 'B') || setweight(to_tsvector( coalesce(\"features\".\"title\", '')), 'A') || setweight(to_tsvector( coalesce(\"features\".\"description\", '')), 'C')), (to_tsquery( ''' ' || 'Spain' || ' ''')))) AS pg_search_rank"]
      (columns.map{ |c| c.name } - ['the_geom']).map{ |c| "#{self.table_name}.#{c}" } + lat_long + pg_search_rank
    end

    # Returns all heritage sites with the specified whs site id (must be only one ALWAYS)
    def by_whs_site_id(id)
      scoped.where('meta like ?', "%:whs_site_id: \"#{id}\"%").limit(1).first
    end

    # Gets the next feature's images without consolidated images
    def next_feature_images
      feature = self.with_gallery.without_consolidated_images.sample

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

      gallery.gallery_entry_ids = pics_ids
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

end

require 'feature.rb'
Feature.send :include, FeatureExtensions
