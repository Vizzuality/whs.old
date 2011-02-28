class AddIndexToMetaInFeatures < ActiveRecord::Migration
  def self.up
    add_index :features, :meta
  end

  def self.down
    remove_index :features, :meta
  end
end
