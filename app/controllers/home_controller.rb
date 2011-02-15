class HomeController < ApplicationController

  before_filter :find_all_features

  def show

    @random_features = @features.sample(9)
    render :action=>"show",:layout=>"home_layout"
    #layout "home_layout"
    #sql="SELECT id from features"
    
  end
  
protected

  def find_all_features
    @features = Feature.find(:all, :order => "position ASC")
  end
  
  
end
