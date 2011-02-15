class FeaturesController < ApplicationController

  before_filter :find_all_features
  before_filter :find_page

  def index
    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    @random_features = @features.sample(9)
    present(@page)
  end

  def show
    @feature        = Feature.find(params[:id])
    @random_feature = Feature.all.reject{|f| f.id == @features.id}.sample
    
    # TODO: Replace with nearest places, currently they are random
    @nearest_places =  @features.sample(3)
    
    # you can use meta fields from your model instead (e.g. browser_title)
    # by swapping @page for @feature in the line below:
    present(@page)
  end

protected

  def find_all_features
    @features = Feature.find(:all, :order => "position ASC")
  end

  def find_page
    @page = Page.find_by_link_url("/features")
  end

end
