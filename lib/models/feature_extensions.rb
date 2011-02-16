module FeatureExtensions
  extend ActiveSupport::Concern

  included  do
    class_eval do

      # Returns all features without consolidated images
      scope :without_consolidated_images, where('meta not like ?', "%:images_consolidated: true%")

      # Returns all features with consolidated images
      scope :with_consolidated_images, where('meta like ?', "%:images_consolidated: true%")

      # Returns all features with a gallery associated
      scope :with_gallery, where('gallery_id IS NOT NULL')

      # Returns features ordered by closest to specified point
      scope :close_to, lambda{|point| select("features.*, ST_Distance(the_geom::geography, GeomFromText('POINT(#{point.x} #{point.y})', 4326)) as distance").order("ST_Distance(the_geom::geography, GeomFromText('POINT(#{point.x} #{point.y})', 4326))")}
    end
  end

  module ClassMethods
    # Returns all heritage sites with the specified whs site id (must be only one ALWAYS)
    def by_whs_site_id(id)
      scoped.where('meta like ?', "%:whs_site_id: \"#{id}\"%").first
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

    def calculate_itinerary_time_to(location)

      itinerary = {:time => '0 hours'}

      if location.present?
        distance = distance_to location

        case
        # Distance is less than 500 meters, we're going by walking
        when distance < 500
          itinerary[:type] = 'walking'
          directions = query_google_directions walking, itinerary[:type]

          # If response is OK, we're using a car
          if directions['status'].eql?('OK')
            if directions.present? && directions['routes'].present? && directions['routes'].first['legs'].present? && directions['routes'].first['legs'].first['duration']
              itinerary[:time] = directions['routes'].first['legs'].first['duration']['text']
            end
          end
        # Distance is between 500 meters and 800 kilometers, we're going by car
        when distance >= 500 && distance < 800_000
          itinerary[:type] = 'car'

          directions = query_google_directions location

          # If response is OK, we're using a car
          if directions['status'].eql?('OK')
            if directions.present? && directions['routes'].present? && directions['routes'].first['legs'].present? && directions['routes'].first['legs'].first['duration']
              itinerary[:time] = directions['routes'].first['legs'].first['duration']['text']
            end
          # If not, we assume, we're going by plane
          else
            itinerary[:type] = 'plane'
            itinerary[:time] = "#{distance/700.to_i} hours"
          end
        # Distance is greater than 800 kilometers, we're going by plane
        when distance >= 800_000
          itinerary[:type] = 'plane'
          itinerary[:time] = "#{distance/700_000.to_i} hours"
        end
      end

      itinerary
    end

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
