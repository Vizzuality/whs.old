module ApplicationHelper

  include Refinery::ApplicationHelper

  def itinerary_time_and_type(itinerary, from)
    return unless itinerary
    "#{distance_of_time_in_words_to_now(itinerary[:time])} by #{itinerary[:type]} from #{from}"
  end

end
