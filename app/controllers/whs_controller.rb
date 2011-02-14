class WhsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:set_feature_images]

  def import_images
    render :layout => false
  end

  def next_feature_images

    result = Feature.next_feature_images

    render :json => result.to_json
  end

  def set_feature_images
    result = Feature.next_feature_images

    if params[:feature_id].present? || params[:pic_ids].present?
      if feature = Feature.by_whs_site_id(params[:feature_id])
        feature.consolidate_images(params[:pic_ids])
      end
    end

    render :json => result.to_json
  end
end