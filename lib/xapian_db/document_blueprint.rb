# encoding: utf-8

# A document blueprint describes the mapping of an object to a Xapian document
# for a given class.
# @author Gernot Kogler

module XapianDb
    
  class DocumentBlueprint

    # ---------------------------------------------------------------------------------   
    # Singleton methods
    # ---------------------------------------------------------------------------------   
    class << self

      # Configure the blueprint for a class
      def setup(klass, &block)
        @blueprints ||= {}
        blueprint = DocumentBlueprint.new
        blueprint.indexer = Indexer.new(blueprint)
        yield blueprint if block_given? # configure the blueprint through the block
        @blueprints[klass] = blueprint
        @adapter = blueprint.adapter || XapianDb::Config.adapter || Adapters::GenericAdapter
        @adapter.add_class_helper_methods_to klass
        @searchable_prefixes = nil # force rebuild of the searchable prefixes
      end
      
      # Get the blueprint for a class
      def blueprint_for(klass)
        @blueprints[klass] if @blueprints
      end

      # Return an array of all configured text methods in any blueprint
      def searchable_prefixes
        return [] unless @blueprints
        return @searchable_prefixes unless @searchable_prefixes.nil?
        prefixes = []
        @blueprints.each do |klass, blueprint|
          prefixes << blueprint.searchable_prefixes
        end
        @searchable_prefixes = prefixes.flatten.compact.uniq
      end
            
    end

    # ---------------------------------------------------------------------------------   
    # Instance methods
    # ---------------------------------------------------------------------------------       
    attr_accessor :indexer
    
    # Return an array of all configured text methods in this blueprint
    def searchable_prefixes
      @prefixes ||= indexed_methods.map{|method_name, options| method_name}
    end
    
    # Lazily build and return a module that implements accessors for each field
    def accessors_module
      return @accessors_module unless @accessors_module.nil?
      @accessors_module = Module.new
      @attributes.each_with_index do |field, index|
        @accessors_module.instance_eval do
          define_method field do
            YAML::load(self.values[index+1].value)
          end
        end
      end
      # Let the adapter add its document helper methods (if any)
      adapter = XapianDb::Config.adapter || XapianDb::Adapters::GenericAdapter
      adapter.add_doc_helper_methods_to(@accessors_module)
      @accessors_module
    end
          
    # ---------------------------------------------------------------------------------   
    # Blueprint DSL methods
    # ---------------------------------------------------------------------------------   
    attr_reader :adapter, :attributes, :indexed_methods
        
    # Construct the blueprint
    def initialize
      @attributes = []
      @indexed_methods = {}
    end
    
    # Set a custom adapter for this blueprint
    def adapter=(adapter)
      @adapter = adapter
    end
    
    # Add an attribute to the list
    # TODO: Make sure the name does not collide with a method name of Xapian::Document since
    # we generate methods in the documents for all defined fields
    def attribute(name, options={})
      opts = {:index => true}.merge(options)
      @attributes << name
      self.index(name, opts) if opts[:index]
    end

    # Add an indexed value to the list
    def index(name, options={})
      @indexed_methods[name] = IndexOptions.new(options)
    end

    # Options for an indexed text
    class IndexOptions      
      attr_accessor :weight
      
      def initialize(options)
        @weight = options[:weight] || 1
      end
    end
          
  end
  
end