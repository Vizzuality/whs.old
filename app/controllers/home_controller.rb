class HomeController < ApplicationController
  def show
    render :action=>"show",:layout=>"home_layout"
    #layout "home_layout"
    #sql="SELECT id from features"
    
  end
end
