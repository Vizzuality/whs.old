class WHS < Feature

  # Returns all heritage sites with the specified whs site id (must be only one ALWAYS)
  scope :by_whs_site_id, lambda{|id| where('meta like ?', "%:whs_site_id: \"#{id}\"%") }

  # Returns all features without consolidated images
  scope :without_consolidated_images, where('meta not like ?', "%:images_consolidated: true%")

  # Returns all features with consolidated images
  scope :with_consolidated_images, where('meta like ?', "%:images_consolidated: true%")

  # Returns all features with a gallery associated
  scope :with_gallery, where('gallery_id IS NOT NULL')

  def self.next_feature_images
    feature = self.with_gallery.without_consolidated_images.sample

    result = nil
    if feature

      images = feature.gallery.gallery_entries.select{|g| g.image }

      if images.present?
        result = {
          :feature_id => feature.whs_site_id,
          :name => feature.title,
          :pics => images.map{|gallery| {:pic_id => gallery.id, :url_big => gallery.image.thumbnail(:large).url, :url_small => gallery.image.thumbnail(:small).url}}
        }
      end
    end
    result
  end

  def consolidate_images(pics_ids)
    pics_ids = pics_ids.split(',').map{|id| id.to_i}

    gallery.gallery_entry_ids = pics_ids
    meta[:images_consolidated] = true
    save!
  end

end