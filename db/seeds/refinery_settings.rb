[
  {:name => "site_name", :value => "RethinkWHS"},
  {:name => "new_page_parts", :value => false},
  {:name => "activity_show_limit", :value => 7},
  {:name => "preferred_image_view", :value => :grid},
  {:name => "analytics_page_code", :value => "UA-xxxxxx-x"},
  # todo: remove these and use dragonfly better instead.
  {:name => "image_thumbnails", :value => {
    :large => '880x430#',
    :small => '293x214#',
    :tiny  => '234x162#'
    }
  }
].each do |setting|
  RefinerySetting.create(:name => setting[:name].to_s, :value => setting[:value], :destroyable => false)
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
