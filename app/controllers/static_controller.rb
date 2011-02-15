class StaticController < ApplicationController
  def about
    features = Feature.all
    @whs_total_count = features.count
    @whs_cultural_count = features.select{|f| f.type && f.type.eql?('cultural')}.count
    @whs_natural_count = features.select{|f| f.type && f.type.eql?('natural')}.count
  end
end
