class AddAuthorFieldsToImages < ActiveRecord::Migration
  def self.up
    add_column :images, :author, :string
    add_column :images, :author_url, :string
  end

  def self.down
    remove_column :images, :author
    remove_column :images, :author_url
  end
end
