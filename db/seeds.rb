r = Role.create :title => 'Refinery'

u = User.new
u.login = 'admin'
u.email = 'change-me@example.com'
u.password = 'admin'
u.password_confirmation = 'admin'
u.save


# Refinery settings
Dir[Rails.root.join('db', 'seeds','*.rb').to_s].each do |file|
  load(file)
end

# Update plugins position
u.reload
%W{ refinery_dashboard refinery_pages features refinerycms_blog events galleries refinery_files refinery_images refinery_inquiries refinery_users refinery_settings }.each_with_index do |plugin, i|
  if p = u.plugins.find_by_name(plugin)
    p.update_attribute(:position, i)
  else
    u.plugins.create(:name => plugin, :position => i)
  end
end

u.roles << r

# Feature attributes
attributes = <<-ATTRIBUTES
endangered:integer
country:string
designation_date:text
designation_criteria:string
size:string
external_links:string
ATTRIBUTES

RefinerySetting.set(:feature_attributes, attributes)

# Image thumbnails sizes
attributes = <<-SIZES
---
:large: 880x430#
:small: 293x214#
SIZES
RefinerySetting.set(:image_thumbnails, attributes)
