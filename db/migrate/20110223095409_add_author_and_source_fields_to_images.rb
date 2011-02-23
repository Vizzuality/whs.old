class AddAuthorAndSourceFieldsToImages < ActiveRecord::Migration
  def self.up
    add_column :images, :author, :string
    add_column :images, :author_url, :string
    add_column :images, :source, :string
  end

  def self.down
    remove_column :images, :author
    remove_column :images, :author_url
    remove_column :images, :source
  end
end
