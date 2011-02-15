current_database  = ActiveRecord::Base.connection.current_database
remote_script_zip = 'ubuntu@stage.vizzuality.com:~/geo_ips.sql.tar.gz'
geo_ips_sql        = "#{Rails.root}/tmp/geo_ips.sql.gz"

# Downloads ipinfo script from dropbox unless it exists in tmp folder
puts ''
puts 'Downloading geo_ips.sql script...'
puts '--------------------------------'
`scp -v #{remote_script_zip} #{geo_ips_sql}` unless File.exists?(geo_ips_sql)

# Since we're inserting about 1,4 million records, we drop the geo_ips table indexes,
# in order to speed up data insertion.
# These indexes are being created afterwards in the ipinfo.sql script
drop_indexes_sentence = <<EOF
  DROP INDEX city_idx;
  DROP INDEX country_name_idx;
  DROP INDEX index_geo_ips_on_ip_start;
  DROP INDEX lower_city_idx;
  DROP INDEX lower_country_name_idx;
EOF

begin
  ActiveRecord::Base.connection.execute(drop_indexes_sentence)
rescue

end


if GeoIp.exists?
  puts ''
  puts 'Emptying geo_ips table...'
  puts '-------------------------'
  GeoIp.delete_all
end

# Loads ipinfo sql script into current environment database
puts ''
puts msg = "Loading ipinfo.sql into #{current_database} database."
puts msg.chars.map{'-'}.join
`cat #{geo_ips_sql} | gunzip | psql -a -Upostgres #{current_database}`

puts ''
puts 'Removing downloaded data...'
puts '---------------------------'
`rm #{geo_ips_sql}`
