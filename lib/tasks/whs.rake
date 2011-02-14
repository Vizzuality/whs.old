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
      %w(edited_region string)
    ]
    RefinerySetting.set(:feature_attributes, feature_attributes.map{|a| a.join(':')}.join("\r\n"))

    load 'feature.rb'

    puts 'Importing features data'
    puts '======================='
    # Hey, look at me!!
    print "\a\a\a" # beep! beep! beep!
    puts 'Destroy previously created Features?'
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
        whs.whs_site_id         = row.whs_site_id
        whs.endangered_reason   = row.endangered_reason
        whs.endangered_year     = row.endangered_year
        whs.name                = row.name
        whs.wikipedia_link      = row.wikipedia_link
        whs.country             = row.country
        whs.iso_code            = row.iso_code
        whs.criteria            = row.criteria
        whs.date_of_inscription = row.date_of_inscription
        whs.size                = row.size_has.to_f.hectare.to.square_meters.value if row.size_has.present?
        whs.region              = row.region
        whs.edited_region       = row.edited_region
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
  task :import_features_images => :environment do
    require 'panoramio'
    require 'net/http'
    require 'uri'

    feature_count = Feature.count

    puts 'Downloading panoramio photos'
    puts '============================'
    features_pg = ProgressBar.new("Features", feature_count)

    errors = []

    counter = 0
    Feature.find_each do |feature|
      radius = feature.size.blank? || feature.size <= 0 ? 100 : Math.sqrt(feature.size) / 2

      bounding_box = Feature.select("ST_Buffer((the_geom)::geography, #{radius}) as the_geom").where(:id => feature.id).first.the_geom.bounding_box

      photos = Panoramio.photos(:minx => bounding_box.first.x,
                                :maxx => bounding_box.last.x,
                                :miny => bounding_box.first.y,
                                :maxy => bounding_box.last.y,
                                :size => 'original')

      puts "Downloading photos for #{feature.title} (#{counter} feature of #{feature_count} - #{counter * 100 / feature_count}%)"
      if photos.present?
        begin

          feature.gallery = Gallery.find_or_create_by_name feature.title
          feature.gallery.gallery_entries.clear

          FileUtils.mkdir_p(Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}")) unless File.directory?(Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}"))

          photos_pg = ProgressBar.new("Feature ##{feature.whs_site_id}", photos.count)

          photos.each_with_index do |photo, index|
            begin
              next if File.exists? Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}/", "#{index}.jpg")

              Net::HTTP.get_response(URI.parse(photo.photo_file_url)) do |response|
                File.open(Rails.root.join("tmp/panoramio/features/#{feature.whs_site_id}/#{index}.jpg"), "a+") do |f|
                  f.write(response.body)
                  image = Image.create! :image => f
                  feature.gallery.gallery_entries.create! :name => "Image for gallery #{feature.gallery.name} #{photo.photo_title}", :image_id => image.id
                end
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

  # desc "Inserts into database all the downloaded images from panoramio"
  # task :import_images do
  #   image = Image.create! :image => image_file
  #   feature.gallery.gallery_entries.create! :name => "Image for gallery #{feature.gallery.name} #{photo.photo_title}", :image_id => image.id
  #   feature.gallery = Gallery.find_or_create_by_name feature.title
  #   feature.gallery.gallery_entries.clear
  # end

end