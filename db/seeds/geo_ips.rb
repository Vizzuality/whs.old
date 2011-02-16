current_database  = ActiveRecord::Base.connection.current_database
remote_script_zip = 'ubuntu@stage.vizzuality.com:~/geo_ips.pg_dump'
geo_ips_sql        = "#{Rails.root}/tmp/geo_ips.pg_dump"

# Downloads ipinfo script from dropbox unless it exists in tmp folder
puts ''
puts '#################################'
puts 'Downloading geo_ips.pg_dump script...'
`scp #{remote_script_zip} #{geo_ips_sql}` unless File.exists?(geo_ips_sql)
puts '... done!'
# Since we're inserting about 1,4 million records, we drop the geo_ips table indexes,
# in order to speed up data insertion.
# These indexes are being created afterwards in the ipinfo.sql script
drop_indexes_sentence = <<-SQL
  DROP INDEX city_idx;
  DROP INDEX country_name_idx;
  DROP INDEX index_geo_ips_on_ip_start;
  DROP INDEX lower_city_idx;
  DROP INDEX lower_country_name_idx;
SQL

begin
  ActiveRecord::Base.connection.execute(drop_indexes_sentence)
rescue Exception => e

end


if GeoIp.exists?
  puts '#########################'
  puts 'Emptying geo_ips table...'
  GeoIp.delete_all
  puts '... done!'
end

# Loads ipinfo sql script into current environment database
puts ''
puts msg = "Loading geo_ips.pg_dump into #{current_database} database."
puts msg.chars.map{'#'}.join
`pg_restore -Upostgres -d #{current_database} -a -F c #{geo_ips_sql}`

puts '###########################'
puts 'Creating indexes for geo_ips table...'
create_indexes_sentence = <<-SQL
  CREATE INDEX city_idx ON geo_ips USING btree (city);
  CREATE INDEX country_name_idx ON geo_ips USING btree (country_name);
  CREATE INDEX index_geo_ips_on_ip_start ON geo_ips USING btree (ip_start);
  CREATE INDEX lower_city_idx ON geo_ips USING btree (lower((city)::text));
  CREATE INDEX lower_country_name_idx ON geo_ips USING btree (lower((country_name)::text));
SQL
ActiveRecord::Base.connection.execute(create_indexes_sentence)
puts '... done!'

puts '###########################'
puts 'Removing downloaded data...'
`rm #{geo_ips_sql}`
puts '... done!'
