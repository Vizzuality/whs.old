namespace :whs do

  desc "Imports initial data from csv files"
  task :import_data => :environment do

    errors = []

    csv = CsvMapper.import(Rails.root.join("db/import_data/whs.csv")) do
      read_attributes_from_file
    end

    puts 'Importing features data'
    puts '======================='
    progressbar = ProgressBar.new("Importing...", csv.count)
    csv.each do |row|
      data = {}

      next unless row.description
      document = Nokogiri::HTML(row.description)

      data[:name]                 = document.css('table tr:eq(1) td p:eq(1) strong').text.strip
      data[:country]              = document.css('table tr:eq(1) td p:eq(1) font:eq(2)').text.strip
      data[:designation_date]     = document.css('table tr:eq(2) td table:eq(2) tr:eq(2) td:eq(2)').text.strip
      data[:designation_criteria] = document.css('table tr:eq(2) td table:eq(2) tr:eq(3) td:eq(2)').text.strip
      data[:unesco_whs_id]        = document.css('table tr:eq(2) td table:eq(2) tr:eq(1) td:eq(2)').text.strip
      data[:size]                 = document.css('table tr:eq(2) td table:eq(2) tr:eq(4) td:eq(2)').text.strip
      data[:official_url]         = document.css('table tr:eq(2) td p:last a').first['href']
      data[:description]          = document.css('table tr:eq(2) td p:eq(1)').text.strip
      data[:description]          = data[:description] == '' ? document.css('table tr:eq(2) td p:eq(2)').text.strip : data[:description]

      geometry = row.geometry.split(',')
      data[:lat] = geometry.shift.delete('<Point><coordinates>').to_f
      data[:lon] = geometry.shift.to_f

      begin
        name = data.delete(:name)
        whs = Feature.find_or_create_by_title(name)
        whs.description = data.delete(:description)
        whs.meta        = data

        whs.the_geom    = Point.from_x_y(data.delete(:lat), data.delete(:lon)).as_wkt

        whs.save!
      rescue Exception => e
        errors << ["Errors saving #{name}", e]
      end

      progressbar.inc
    end
    progressbar.finish
    if errors.present?
      puts 'There were some errors in the import process'
      puts '============================================'
      errors.each do |error|
        puts "- #{error.first}"
        puts "  #{error.last}"
      end
    end
  end

end