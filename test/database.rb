task = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new({
  'adapter' => 'postgresql',
  'database' => "activerecord-filter-test"
})
task.drop
task.create

ActiveRecord::Base.establish_connection({
  adapter:  "postgresql",
  database: "activerecord-filter-test",
  encoding: "utf8"
})

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Schema.define do

    create_table "accounts", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  'photos_count', null: false, default: 0
    end
    
    create_table "photos", force: :cascade do |t|
      t.integer  "account_id"
      t.integer  "property_id"
      t.string   "format",                 limit: 255
    end
    
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.string   "aliases",              default: [],   array: true
      t.text     "description"
      t.integer  "constructed"
      t.decimal  "size"
      # t.json     "amenities",                     default: {}, null: false
      t.datetime "created_at",                         null: false
      # t.geometry "location",             limit: {:type=>"Point", :srid=>"4326"}
      t.boolean  "active",             default: false
    end

    create_table "regions", force: :cascade do |t|
    end
    
    create_table "properties_regions", id: false, force: :cascade do |t|
      t.integer "property_id", null: false
      t.integer "region_id",  null: false
    end
    
    create_table "regions_regions", id: false, force: :cascade do |t|
      t.integer "parent_id", null: false
      t.integer "child_id",  null: false
    end
    
    create_table "views", force: :cascade do |t|
      t.string  "subject_type"
      t.integer "subject_id"
    end

  end
end

class Account < ActiveRecord::Base
  
  has_many :photos
  
end

class Photo < ActiveRecord::Base
  
  belongs_to :account, :counter_cache => true
  has_and_belongs_to_many :properties

end

class View < ActiveRecord::Base
  belongs_to :subject, polymorphic: true
end

class Property < ActiveRecord::Base
  
  has_many :photos

  has_and_belongs_to_many :regions
  
  filter_on :state, ->(v) {
    filter(:name => v.upcase)
  }
  
end

class Region < ActiveRecord::Base

  has_and_belongs_to_many :properties
  has_and_belongs_to_many :parents, :join_table => 'regions_regions', :class_name => 'Region', :foreign_key => 'child_id', :association_foreign_key => 'parent_id'
  has_and_belongs_to_many :children, :join_table => 'regions_regions', :class_name => 'Region', :foreign_key => 'parent_id', :association_foreign_key => 'child_id'
  
end