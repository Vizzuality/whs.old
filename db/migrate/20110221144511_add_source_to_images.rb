class AddSourceToImages < ActiveRecord::Migration
  def self.up
    add_column :images, :source, :string
  end

  def self.down
    remove_column :images, :source
  end
end
