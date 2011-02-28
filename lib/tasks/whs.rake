namespace :whs do

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

    if Rails.env.development?
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

    features_without_images = feature_count = destroy_images = features_pg = errors = start_time = counter = radius = bounding_box = photos = progress_so_far = left = elapsed_time = time_to_finish = time_left = photos_pg = nil

    
    features_without_images = Feature.all
    feature_count = features_without_images.count

    puts 'Downloading panoramio photos'
    puts '============================'

    if Rails.env.development?
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
    end

    features_pg = ProgressBar.new("Features", feature_count)

    errors     = []
    start_time = Time.now
    counter    = 1


    features_without_images.each do |feature|
      radius = feature.size.blank? || feature.size <= 0 ? 100 : Math.sqrt(feature.size) / 2

      bounding_box = Feature.select("ST_Buffer((the_geom)::geography, #{radius}) as the_geom").where(:id => feature.id).first.the_geom.bounding_box

      photos = Panoramio.photos(:minx => bounding_box.first.x,
                                :maxx => bounding_box.last.x,
                                :miny => bounding_box.first.y,
                                :maxy => bounding_box.last.y,
                                :size => 'original')

      progress_so_far = counter * 100.0 / feature_count
      left = 100.0 - progress_so_far
      elapsed_time = Time.now - start_time
      time_to_finish = (elapsed_time * left / progress_so_far).seconds
      time_left = distance_of_time_in_words(start_time, start_time + time_to_finish)
      puts "Downloading photos for #{feature.title} (feature #{counter} of #{feature_count} - #{progress_so_far.to_i}% - #{time_left} left)"
      if photos.present?
        begin

          feature.gallery = Gallery.find_or_create_by_name feature.title.truncate(255)
          feature.gallery.gallery_entries.clear
          feature.save

          photos_pg = ProgressBar.new("Feature ##{feature.whs_site_id}", photos.count)
          photos.each do |photo|
            begin
              download_and_save_image photo.photo_file_url, photo.photo_title, photo.photo_id, photo.owner_name, photo.owner_url, feature, 'panoramio'
            rescue Exception => e
              errors << ["Errors downloading image for feature ##{feature.id}, photo => #{photo.photo_file_url}", e]
            end

            photos_pg.inc
          end
          photos_pg.finish
        rescue Exception => e
          errors << ["Errors downloading images for feature ##{feature.id} - #{feature.title}", e]
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

    amount_without_description = Feature.where(:description => nil).count
    pg = ProgressBar.new("Importing...", amount_without_description)
    errors = []
    scrapped = 0

    Feature.where(:description => nil).each do |feature|
      begin
        # Percentages are bad encoded as '%25' in original data import
        wikipedia_url = URI.parse(feature.wikipedia_link.gsub('%25', '%'))

        doc = Nokogiri::HTML(Net::HTTP.get_response(wikipedia_url).body)

        description = doc.css('div#bodyContent > p')

        # Removes cites links
        description.css('a[href^="#cite_note"]').remove

        feature.description    = description.map(&:text).join("\n\n")
        feature.external_links = doc.css('#bodyContent ul li a.external.text').map{|a| "[#{a.text}|#{a['href']}]"}.first(5).join('#')

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
    puts "#{scrapped} wikipedia pages scrapped from #{amount_without_description}"

  end

  desc "Imports missing wikipedia pages"
  task :import_missing_wikipedia => :environment do

    csv = CsvMapper.import(Rails.root.join("db/import_data/whs-no-wikipedia.csv")) do
      read_attributes_from_file
    end

    csv.each do |row|
      f = Feature.find(row.id)
      f.description    = row.description
      f.save!
    end
  end

  desc "Exports current database to a gzipped sql file"
  task :export_database => :environment do
    current_database = ActiveRecord::Base.connection.current_database
    file_path        = Rails.root.join('db/scripts/features.sql')

    puts '############################'

    puts "Exporting #{current_database} database..."
    `pg_dump -Upostgres -f #{file_path} #{current_database}`
    puts '... done!'

    puts ''
    puts 'Compressing...'
    `gzip #{file_path}`
    puts '... done!'

    puts ''
    puts 'Database export complete!'
    puts '#########################'
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

  def download_and_save_image(photo_url, photo_title, photo_id, owner_name, owner_url, feature, image_source)
    response = Net::HTTP.get_response(URI.parse(photo_url))
    # Photo moved
    if response.code == '302'
      begin
        # Gets the new photo url
        moved_photo_url = response['Location'] || response.body.scan(/<A HREF=\"(.*)\">here<\/A>/).to_s
        download_and_save_image moved_photo_url, photo_title, photo_id, owner_name, owner_url, feature, image_source
      rescue Exception => e
        puts e
      end

    else
      save_image feature, response.body, photo_title, photo_id, owner_name, owner_url, image_source
    end
  end

  def save_image(feature, bytes, photo_title, photo_id, owner_name, owner_url, image_source)
    image = Image.create! :image => bytes, :author => owner_name, :author_url => owner_url, :source => image_source
    feature.gallery.gallery_entries.create! :name => "Image for gallery #{feature.gallery.name}. #{photo_title} ##{photo_id}", :image_id => image.id
  end
end
