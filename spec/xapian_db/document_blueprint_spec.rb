# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe XapianDb::DocumentBlueprint do

  describe ".searchable_prefixes" do

    it "should return an array of all method names configured to be indexed" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.index :id
        blueprint.index :name
      end
      XapianDb::DocumentBlueprint.searchable_prefixes.should include(:id, :name)
    end

    it "should return an array with unique values" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.index :id
        blueprint.index :name
      end
      XapianDb::DocumentBlueprint.setup(Object) do |blueprint|
        blueprint.index :id
        blueprint.index :name
      end
      XapianDb::DocumentBlueprint.searchable_prefixes.select{|prefix| prefix == :id}.size.should ==1
      XapianDb::DocumentBlueprint.searchable_prefixes.select{|prefix| prefix == :name}.size.should ==1
    end

    it "should return an empty array if no blueprints are configured" do
      # We have to reload the DocumentBlueprint to get rid aof any configurations
      XapianDb.send(:remove_const, 'DocumentBlueprint')
      load File.expand_path(File.dirname(__FILE__) + '/../../lib/xapian_db/document_blueprint.rb')
      XapianDb::DocumentBlueprint.searchable_prefixes.should == []
    end

  end

  describe ".setup (singleton)" do
    it "stores a blueprint for a given class" do
      XapianDb::DocumentBlueprint.setup(IndexedObject)
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).should be_a_kind_of(XapianDb::DocumentBlueprint)
    end

  end

  describe ".adapter=" do
    it "sets the adpater for the configured class" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.adapter = DemoAdapter
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).adapter.should == DemoAdapter
    end
  end

  describe "language_method" do
    it "sets the method name to retrieve a language from an object" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.language_method :lang_cd
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).lang_method.should == :lang_cd
    end
  end

  describe ".attribute" do

    before :each do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attribute :id
      end
    end

    it "adds an attribute to the blueprint" do
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).attributes_collection.should include(:id)
    end

    it "adds the attribute to the indexed methods by default" do
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash.should include(:id)
    end

    it "does not index the attribute if the :index option ist set to false " do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attribute :id, :index => false
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash.should_not include(:id)
    end

    it "allows to specify a weight for the attribute" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attribute :id, :weight=> 10
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash[:id].weight.should == 10
    end

  end

  describe ".attributes" do

    it "allows to declare one single attribute" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attributes :id
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).attributes_collection.should include(:id)
    end

    it "allows to declare multiple attributes in a single statement (but without options)" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attributes :id, :name
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).attributes_collection.should include(:id, :name)
    end

  end

  describe ".index" do

    before :all do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.index :id
      end
    end

    it "adds an indexed value to the blueprint" do
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash[:id].should be
    end

    it "defaults the weight option to 1" do
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash[:id].weight.should == 1
    end

    it "accepts weight as an option" do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.index :id, :weight => 10
      end
      XapianDb::DocumentBlueprint.blueprint_for(IndexedObject).indexed_methods_hash[:id].weight.should == 10
    end

  end

  describe ".accessors_module" do

    before :each do
      XapianDb::DocumentBlueprint.setup(IndexedObject) do |blueprint|
        blueprint.attribute :id
        blueprint.attribute :name
        blueprint.attribute :date_of_birth
        blueprint.attribute :empty_field
        blueprint.attribute :array
      end
      @blueprint = XapianDb::DocumentBlueprint.blueprint_for(IndexedObject)

      @doc = Xapian::Document.new
      @doc.add_value(0, "IndexedObject")
      @doc.add_value(1, 1.to_yaml)
      @doc.add_value(2, "Kogler".to_yaml)
      @doc.add_value(3, Date.today.to_yaml)
      @doc.add_value(4, nil.to_yaml)
      @doc.add_value(5, [1, "two", Date.today].to_yaml)
      @doc.extend @blueprint.accessors_module
    end

    it "builds an accessor module for the blueprint" do
      @blueprint.accessors_module.should be_a_kind_of Module
    end

    it "adds accessor methods for each configured field" do
      @blueprint.accessors_module.instance_methods.should include(:id, :name, :date_of_birth)
    end

    it "adds accessor methods that can handle nil" do
      @doc.empty_field.should be_nil
    end

    it "adds an accessor method for the class of the indexed object" do
      @doc.indexed_class.should == "IndexedObject"
    end

    it "adds accessor methods that deserialize values using YAML" do
      @doc.date_of_birth.should == Date.today
      @doc.array.should == [1, "two", Date.today]
    end

  end

end