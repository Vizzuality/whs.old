namespace :whs do

  desc "Setup all data for the site"
  task :setup => ['db:reset', :import_data, :import_wikipedia_data, :import_panoramio_photos]

  desc "Imports initial data from csv files"
  task :import_data => :environment do

    errors = []

    csv = CsvMapper.import(Rails.root.join("db/import_data/whs.csv")) do
      read_attributes_from_file
    end

    feature_attributes = [
      %w(whs_source_page string),
      %w(comments string),
      %w(whs_site_id string),
      %w(endangered_reason string),
      %w(endangered_year integer),
      %w(name string),
      %w(wikipedia_link string),
      %w(country string),
      %w(iso_code string),
      %w(criteria string),
      %w(date_of_inscription datetime),
      %w(size float),
      %w(region string),
      %w(edited_region string),
      %w(type string),
      %w(external_links string)
    ]
    RefinerySetting.set(:feature_attributes, feature_attributes.map{|a| a.join(':')}.join("\r\n"))

    load 'feature.rb'

    puts 'Importing features data'
    puts '======================='
    # Hey, look at me!!
    3.times{ sleep 0.2; print "\a" } # beep! beep! beep!
    puts 'Destroy previously created features?'
    print '(yes/no*) >> '
    STDOUT.flush
    destroy_features = STDIN.gets.chomp
    if destroy_features == 'yes'
      puts 'Destroying features...'
      Feature.destroy_all
      puts '... done!'
    end
    progressbar = ProgressBar.new("Importing...", csv.count)
    csv.each do |row|

      begin
        whs = Feature.find_or_create_by_title(row.edited_name)

        whs.title               = row.edited_name
        whs.whs_source_page     = row.whs_source_page
        whs.comments            = row.comments
        whs.whs_site_id         = row.whs_site_id.to_i.to_s if row.whs_site_id
        whs.endangered_reason   = row.endangered_reason
        whs.endangered_year     = row.endangered_year
        whs.name                = row.name
        whs.wikipedia_link      = row.wikipedia_link
        whs.country             = row.country
        whs.iso_code            = row.iso_code
        whs.criteria            = row.criteria.split(',').map{|c| "[#{c}]"}.join(',') if row.criteria
        whs.date_of_inscription = row.date_of_inscription
        whs.size                = row.size_has.to_f.hectare.to.square_meters.value if row.size_has.present?
        whs.region              = row.region
        whs.edited_region       = row.edited_region
        whs.type                = row.type
        whs.the_geom            = Point.from_x_y(row.longitude, row.latitude).as_wkt

        whs.save!
      rescue Exception => e
        errors << ["Errors saving #{row.whs_site_id} - #{row.name}", e]
      end

      progressbar.inc
    end
    progressbar.finish
    if errors.present?
      puts 'There were some errors in the import process'
      puts '============================================'
      errors.each do |error|
        puts "- #{error.first}"
        puts "  error message: #{error.last.message}"
      end
    end
  end

  desc "Imports panoramio images for each feature"
  task :import_panoramio_photos => :environment do
    require 'panoramio'
    require 'net/http'
    require 'uri'

    include ActionView::Helpers::DateHelper

    feature_count = Feature.count

    puts 'Downloading panoramio photos'
    puts '============================'

    # Hey, look at me!!
    3.times{ sleep 0.2; print "\a" } # beep! beep! beep!
    puts 'Destroy previously created galleries and images?'
    print '(yes/no*) >> '
    STDOUT.flush
    destroy_images = STDIN.gets.chomp
    if destroy_images == 'yes'
      puts 'Destroying galleries and images...'
      Gallery.destroy_all
      Image.destroy_all
      puts '... done!'
    end

    features_pg = ProgressBar.new("Features", feature_count)

    errors     = []
    start_time = Time.now
    counter    = 1

    Feature.find_each do |feature|
      radius = feature.size.blank? || feature.size <= 0 ? 100 : Math.sqrt(feature.size) / 2

      bounding_box = Feature.select("ST_Buffer((the_geom)::geography, #{radius}) as the_geom").where(:id => feature.id).first.the_geom.bounding_box

      photos = Panoramio.photos(:minx => bounding_box.first.x,
                                :maxx => bounding_box.last.x,
                                :miny => bounding_box.first.y,
                                :maxy => bounding_box.last.y,
                                :size => 'original')

      time_to_finish = ((Time.now - start_time) * feature_count / counter).seconds
      time_left = distance_of_time_in_words(start_time, start_time + time_to_finish)
      puts "Downloading photos for #{feature.title} (feature #{counter} of #{feature_count} - #{counter * 100 / feature_count}% - #{time_left} left)"
      if photos.present?
        begin

          feature.gallery = Gallery.find_or_create_by_name feature.title
          feature.gallery.gallery_entries.clear

          FileUtils.mkdir_p(Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}")) unless File.directory?(Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}"))

          photos_pg = ProgressBar.new("Feature ##{feature.whs_site_id}", photos.count)
          photos.each do |photo|
            begin
              image_file_path = Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}/", "#{photo.photo_id}.jpg")

              unless File.exists? image_file_path
                download_and_save_image photo.photo_file_url, photo.photo_title, photo.photo_id, image_file_path, photo.owner_name, photo.owner_url, feature
              else
                save_image feature, File.open(image_file_path), photo.photo_title, photo.photo_id, photo.owner_name, photo.owner_url
              end

            rescue Exception => e
              errors << ["Errors downloading image for #{photo.photo_title}", e]
            end

            photos_pg.inc
          end
          feature.save!
          photos_pg.finish
        rescue Exception => e
          errors << ["Errors downloading images for #{feature.title}", e]
        end
      end
      features_pg.inc
      counter += 1
    end
    features_pg.finish
    if errors.present?
      puts 'There were some errors in the import process'
      puts '============================================'
      errors.each do |error|
        puts "- #{error.first}"
        puts "  error message: #{error.last.message}"
      end
    end
  end

  desc "Gets wikipedia description and related links for each feature"
  task :import_wikipedia_data => :environment do
    require 'net/http'
    require 'uri'

    puts 'Importing data from wikipedia'
    puts '============================='

    features_without_description = Feature.where(:description => nil)
    pg = ProgressBar.new("Importing...", features_without_description.count)
    errors = []
    scrapped = 0

    features_without_description.each do |feature|
      begin
        # Percentages are bad encoded as '%25' in original data import
        wikipedia_url = URI.parse(CGI::unescape(feature.wikipedia_link.gsub('%25', '%')))

        doc = Nokogiri::HTML(Net::HTTP.get_response(wikipedia_url).body)

        description = doc.css('div#bodyContent > p')

        # Removes cites links
        description.css('a[href^="#cite_note"]').remove

        feature.description    = description.map(&:text).join("\n\n")
        feature.external_links = doc.css('#bodyContent ul li a.external.text').map{|a| "[#{a.text}|#{a['href']}]"}.join(',').first(5)

        feature.save!
        pg.inc
        scrapped += 1
      rescue Exception => e
        errors << ["Errors importing wikipedia data for #{feature.title}", e]
      end
    end

    pg.finish

    errors_report errors

    puts '#####################################################'
    puts "#{scrapped} wikipedia pages scrapped from #{features_without_description.count}"

  end

  def errors_report(errors)
    if errors.present?
      puts '############################################'
      puts 'There were some errors in the import process'
      puts '============================================'
      errors.each do |error|
        puts "- #{error.first}"
        puts "  error message: #{error.last.message}"
      end
    end
  end

  def download_and_save_image(photo_url, photo_title, photo_id, file_path, owner_name, owner_url, feature)
    Net::HTTP.get_response(URI.parse(photo_url)) do |response|
      # Photo moved
      if response.code == '302'
        # Gets the new photo url
        moved_photo_url = Nokogiri::HTML(response.body).css('a').first['href']
        download_and_save_image moved_photo_url, photo_title, photo_id, file_path, owner_name, owner_url, feature
      else
        open(file_path, "w+") do |f|
          f.write(response.body)
          save_image feature, f, photo_title, photo_id, owner_name, owner_url
        end
      end
    end
  end

  def save_image(feature, file, photo_title, photo_id, owner_name, owner_url)
    image = Image.create! :image => file, :author => owner_name, :author_url => owner_url
    feature.gallery.gallery_entries.create! :name => "Image for gallery #{feature.gallery.name}. #{photo_title} ##{photo_id}", :image_id => image.id
  end
end
