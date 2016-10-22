module GraphQL
  module Define
    # This module provides the `.define { ... }` API for
    # {GraphQL::BaseType}, {GraphQL::Field} and others.
    #
    # Calling `.accepts_definitions(...)` creates:
    #
    # - a keyword to the `.define` method
    # - a helper method in the `.define { ... }` block
    #
    # The `.define { ... }` block will be called lazily. To be sure it has been
    # called, use the private method `#ensure_defined`. That will call the
    # definition block if it hasn't been called already.
    #
    # The goals are:
    #
    # - Minimal overhead in consuming classes
    # - Independence between consuming classes
    # - Extendable by third-party libraries without monkey-patching or other nastiness
    #
    # @example Make a class definable
    #   class Car
    #     attr_accessor :make, :model
    #     accepts_definitions(
    #       # These attrs will be defined with plain setters, `{attr}=`
    #       :make, :model,
    #       # This attr has a custom definition which applies the config to the target
    #       doors: ->(car, doors_count) { doors_count.times { car.doors << Door.new } }
    #     )
    #
    #     def initialize
    #       @doors = []
    #     end
    #   end
    #
    #   # Create an instance with `.define`:
    #   subaru_baja = Car.define do
    #     make "Subaru"
    #     model "Baja"
    #     doors 4
    #   end
    #
    #   # The custom proc was applied:
    #   subaru_baja.doors #=> [<Door>, <Door>, <Door>, <Door>]
    #
    # @example Extending the definition of a class
    #   # Add some definitions:
    #   Car.accepts_definitions(all_wheel_drive: GraphQL::Define.assign_metadata_key(:all_wheel_drive))
    #
    #   # Use it in a definition
    #   subaru_baja = Car.define do
    #     # ...
    #     all_wheel_drive true
    #   end
    #
    #   # Access it from metadata
    #   subaru_baja.metadata[:all_wheel_drive] # => true
    #
    module InstanceDefinable
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Set the definition block for this instance.
      # It can be run later with {#ensure_defined}
      def definition_proc=(defn_block)
        @definition_proc = defn_block
      end

      # `metadata` can store arbitrary key-values with an object.
      #
      # @return [Hash<Object, Object>] Hash for user-defined storage
      def metadata
        ensure_defined
        @metadata ||= {}
      end

      # Mutate this instance using functions from its {.definition}s.
      # Keywords or helpers in the block correspond to keys given to `accepts_definitions`.
      #
      # Note that the block is not called right away -- instead, it's deferred until
      # one of the defined fields is needed.
      # @return [void]
      def define(**kwargs, &block)
        if @definition_proc
          raise("This instance has already been defined; a second definition is not supported")
        end

        @definition_proc = ->(obj) {
          kwargs.each do |keyword, value|
            public_send(keyword, value)
          end

          if block
            instance_eval(&block)
          end
        }
        nil
      end

      private

      # Run the definition block if it hasn't been run yet.
      # This can only be run once: the block is deleted after it's used.
      # You have to call this before using any value which could
      # come from the definition block.
      # @return [void]
      def ensure_defined
        if @definition_proc
          defn_proc = @definition_proc
          @definition_proc = nil
          proxy = DefinedObjectProxy.new(self)
          proxy.instance_eval(&defn_proc)
        end
        nil
      end

      module ClassMethods
        # Create a new instance
        # and prepare a definition using its {.definitions}.
        # @param kwargs [Hash] Key-value pairs corresponding to defininitions from `accepts_definitions`
        # @param block [Proc] Block which calls helper methods from `accepts_definitions`
        def define(**kwargs, &block)
          instance = self.new
          instance.define(**kwargs, &block)
          instance
        end

        # Attach definitions to this class.
        # Each symbol in `accepts` will be assigned with `{key}=`.
        # The last entry in accepts may be a hash of name-proc pairs for custom definitions.
        def accepts_definitions(*accepts)
          new_assignments = if accepts.last.is_a?(Hash)
            accepts.pop.dup
          else
            {}
          end

          accepts.each do |key|
            new_assignments[key] = AssignAttribute.new(key)
          end

          @own_dictionary = own_dictionary.merge(new_assignments)
        end

        # @return [Hash] combined definitions for self and ancestors
        def dictionary
          if superclass.respond_to?(:dictionary)
            own_dictionary.merge(superclass.dictionary)
          else
            own_dictionary
          end
        end

        # @return [Hash] definitions for this class only
        def own_dictionary
          @own_dictionary ||= {}
        end

        # The methods defined in this block will ensure that the `.define`
        # block has been executed before they run.
        def lazy_methods(&lazy_definition)
          GraphQL::Define::LazyMethodProxy.create(self, &lazy_definition)
        end
      end

      class AssignMetadataKey
        def initialize(key)
          @key = key
        end

        def call(defn, value)
          defn.metadata[@key] = value
        end
      end

      class AssignAttribute
        def initialize(attr_name)
          @attr_assign_method = :"#{attr_name}="
        end

        def call(defn, value)
          defn.public_send(@attr_assign_method, value)
        end
      end
    end
  end
end
