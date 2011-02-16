class ApplicationController < ActionController::Base

  include Refinery::ApplicationController

  before_filter :geolocate_user

  def geolocate_user
    if Rails.env.production?
      unless session[:user_location].present?
        geo_ip = GeoIp.where_ip(request.env[:REMOTE_ADDR]).first
        session[:user_location] = {:lat => geo_ip.latitude, :lon => geo_ip.longitude} unless geo_ip.blank?
      end
    else
      unless session[:user_location].present?
        public_ip = (require 'open-uri' ; open("http://myip.dk") { |f| /([0-9]{1,3}\.){3}[0-9]{1,3}/.match(f.read)[0].to_a[0] })
        geo_ip = GeoIp.where_ip(public_ip).first
        session[:user_location] = {:lat => geo_ip.latitude, :lon => geo_ip.longitude} unless geo_ip.blank?
      end
    end
  end
  private :geolocate_user

end
