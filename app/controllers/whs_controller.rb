class WhsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:set_feature_images]

  def import_images
    render :layout => false
  end

  def next_feature_images

    result = WHS.next_feature_images

    render :json => result.to_json
  end

  def set_feature_images
    result = WHS.next_feature_images

    if params[:feature_id].present? || params[:pic_ids].present?
      # params => {"action"=>"set_feature_images", "pic_ids"=>"5749", "feature_id"=>"739", "controller"=>"whs", "locale"=>:en}
      feature = Feature.find(params[:feature_id])
      pics_ids = params[:pic_ids].split(',').map{|id| id.to_i}

      feature.gallery.gallery_entry_ids = pics_ids
      feature.meta[:images_consolidated] = true
      feature.save!
    end

    render :json => result.to_json
  end
end