require 'capistrano/ext/multistage'
require 'config/boot'
require "bundler/capistrano"

set :stages, %w(staging production)
set :default_stage, "production"

default_run_options[:pty] = true

set :application, 'whs'

set :scm, :git
set :git_shallow_clone, 1
set :scm_user, 'ubuntu'
set :repository, "git://github.com/Vizzuality/whs.git"
ssh_options[:forward_agent] = true
set :keep_releases, 5

set :linode_staging, '178.79.131.104'
set :linode_production, '178.79.142.149'
set :user,  'ubuntu'

set :deploy_to, "/home/ubuntu/www/#{application}"

after "deploy:update_code", :symlinks, :run_migrations, :asset_packages
after "deploy", "deploy:cleanup"

desc "Restart Application"
deploy.task :restart, :roles => [:app] do
  run "touch #{current_path}/tmp/restart.txt"
end

desc "Migrations"
task :run_migrations, :roles => [:app] do
  run <<-CMD
    export RAILS_ENV=#{stage} &&
    cd #{release_path} &&
    rake db:migrate
  CMD
end

task :symlinks, :roles => [:app] do
  run <<-CMD
    ln -s #{shared_path}/dragonfly #{release_path}/tmp/;
    ln -nfs #{shared_path}/config/app_config.yml #{release_path}/config/app_config.yml;
  CMD
end

namespace :whs do
  desc "Imports init data"
  task :import_data, :roles => [:app] do
    run <<-CMD
      export RAILS_ENV=#{stage} &&
      cd #{current_path} &&
      rake whs:setup
    CMD
  end

  task :upload_yml_files, :roles => :app do
    run "mkdir #{deploy_to}/shared/config ; true"
    upload("config/app_config.yml", "#{deploy_to}/shared/config/app_config.yml")
  end

end

desc 'Create asset packages'
task :asset_packages, :roles => [:app] do
 run <<-CMD
   export RAILS_ENV=#{stage} &&
   cd #{release_path} &&
   rake asset:packager:build_all
 CMD
end