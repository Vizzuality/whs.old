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
      public_ip = "87.216.186.246"
      geo_ip = GeoIp.where_ip(public_ip).first
      session[:user_location] = {:lat => geo_ip.latitude, :lon => geo_ip.longitude, :city => geo_ip.city, :country => geo_ip.country_name} unless geo_ip.blank?
    end
  end
  private :geolocate_user

  def user_geolocated?
    session[:user_location] && session[:user_location][:lon] && session[:user_location][:lat]
  end

  def user_city
    city = ''
    city = session[:user_location][:city].capitalize if user_geolocated? && session[:user_location][:city]
    city
  end

  def user_latlong
    Point.from_x_y(session[:user_location][:lon], session[:user_location][:lat]) if user_geolocated?
  end

end
