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
    # Hey, look at me!!
    3.times{ sleep 0.2; print "\a" } # beep! beep! beep!
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

  desc "Loads into database images from tmp/panoramio"
  task :import_images => :environment do

    puts 'Importing images into database'
    puts '=============================='

    errors = []
    total_images = 0
    imported_images = 0

    features_folders = Dir[Rails.root.join("tmp/panoramio/features/*")]
    features_folders.each_with_index do |feature_folder, index|

      whs_site_id = feature_folder.match(/.*\/(\d+)$/)[1]

      if whs_site_id
        feature = Feature.by_whs_site_id(whs_site_id)

        next if feature.nil?

        feature.gallery = Gallery.find_or_create_by_name feature.title
        feature.gallery.gallery_entries.clear

        puts "Importing photos for #{feature.title} (#{index} feature of #{features_folders.size} - #{index * 100 / features_folders.size}%)"

        feature_images = Dir["#{feature_folder}/*"]
        photos_pg = ProgressBar.new("Feature ##{feature.whs_site_id}", feature_images.count)

        total_images += feature_images.count

        feature_images.each_with_index do |feature_image, image_index|
          begin
            File.open(feature_image) do |f|
              image = Image.create! :image => f
              feature.gallery.gallery_entries.create! :name => "Image #{image_index} for gallery #{feature.gallery.name}", :image_id => image.id
            end

            imported_images += 1
          rescue Exception => e
            errors << ["Errors importing images for #{feature.title}", e]
          end

          photos_pg.inc
        end

        feature.meta[:images_consolidated] = false
        feature.save!

        photos_pg.finish

      end
    end

    if errors.present?
      puts '############################################'
      puts 'There were some errors in the import process'
      puts '============================================'
      errors.each do |error|
        puts "- #{error.first}"
        puts "  error message: #{error.last.message}"
      end
    end
    puts '#####################################################'
    puts "#{imported_images} images imported of #{total_images}"
  end

  desc "Clean invalid image files from tmp/panoramio"
  task :clean_invalid_image_files do
    puts '#########################'
    puts 'Cleaning invalid image files'
    puts '-------------------------'
    puts 'Detecting invalid files...'

    image_files_paths = Dir[Rails.root.join("tmp/panoramio/features/**/*")]
    pg = ProgressBar.new("Detecting...", image_files_paths.count)

    invalid_images = []
    image_files_paths.each do |p|
      mime = `file --mime -b #{p}`
      invalid_images << p unless mime.match(/image\/.+/) || mime.match(/application\/x-directory/)
      pg.inc
    end
    pg.finish
    puts '... done!'

    puts '-------------------------'
    puts 'Deleting invalid files...'
    pg = ProgressBar.new("Deleting...", invalid_images.count)
    invalid_images.each do |image_path|
      FileUtils.rm(image_path)
      pg.inc
    end
    pg.finish
    puts '... done!'
    puts '#######################'
    puts "Process terminated. #{invalid_images.count} files deleted."
  end

  desc "Gets wikipedia description and related links for each feature"
  task :import_wikipedia_data => :environment do
    require 'open-uri'

    puts 'Importing data from wikipedia'
    puts '============================='

    pg = ProgressBar.new("Importing...", Feature.count)
    errors = []
    scrapped = 0

    Feature.all.each do |feature|
      begin
        doc = Nokogiri::HTML(open(feature.wikipedia_link))
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
    puts "#{scrapped} wikipedia pages scrapped from #{Feature.count}"

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
end
