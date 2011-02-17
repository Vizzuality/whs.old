Refinery::Application.routes.draw do

  filter(:refinery_locales) if defined?(RoutingFilter::RefineryLocales) # optionally use i18n.

  root :to => 'home#show'
  match 'sitemap', :to => 'pages#sitemap'
  match '/about', :to => 'static#about', :as => 'about'
  match 'whs/:action', :to => 'whs#:action'

  scope(:path => 'refinery', :as => 'admin', :module => 'admin') do
    root :to => 'dashboard#index'
  end

end
