class WHS < Feature

  # Find a world heritage site using its external whs site id
  def self.find_by_whs_site_id(id)
    self.where('meta like ?', "%:whs_site_id: \"#{id}\"%")
  end

end