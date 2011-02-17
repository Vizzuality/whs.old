class StaticController < ApplicationController
  def about
    features            = Feature.scoped
    @whs_total_count    = features.count
    @whs_cultural_count = features.with_type('cultural').count
    @whs_natural_count  = features.with_type('natural').count
  end
end
