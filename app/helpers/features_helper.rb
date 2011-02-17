module FeaturesHelper
  def all_selected?
    css_class = ''
    css_class = 'selected' if params && params[:type].blank?
  end

  def natural_selected?
    css_class = ''
    css_class = 'selected' if params && params[:type] && params[:type].eql?('natural')
  end

  def cultural_selected?
    css_class = ''
    css_class = 'selected' if params && params[:type] && params[:type].eql?('cultural')
  end
end