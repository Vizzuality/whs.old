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
