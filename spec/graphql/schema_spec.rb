require "spec_helper"

describe GraphQL::Schema do
  let(:schema) { DummySchema }
  let(:relay_schema)  { StarWarsSchema }
  let(:empty_schema) { GraphQL::Schema.define }

  describe "#rescue_from" do
    let(:rescue_middleware) { schema.middleware.first }

    it "adds handlers to the rescue middleware" do
      assert_equal(1, rescue_middleware.rescue_table.length)
      # normally, you'd use a real class, not a symbol:
      schema.rescue_from(:error_class) { "my custom message" }
      assert_equal(2, rescue_middleware.rescue_table.length)
    end
  end

  describe "#subscription" do
    it "calls fields on the subscription type" do
      res = schema.execute("subscription { test }")
      assert_equal("Test", res["data"]["test"])
    end
  end

  describe "#resolve_type" do
    describe "when the return value is nil" do
      it "returns nil" do
        result = relay_schema.resolve_type(123, nil)
        assert_equal(nil, result)
      end
    end

    describe "when the return value is not a BaseType" do
      it "raises an error " do
        err = assert_raises(RuntimeError) {
          relay_schema.resolve_type(:test_error, nil)
        }
        assert_includes err.message, "not_a_type (Symbol)"
      end
    end

    describe "when the hook wasn't implemented" do
      it "raises not implemented" do
        assert_raises(NotImplementedError) {
          empty_schema.resolve_type(nil, nil)
        }
      end
    end

    describe "when a schema is defined with abstract types, but no resolve type hook" do
      it "raises not implemented" do
        interface = GraphQL::InterfaceType.define do
          name "SomeInterface"
        end

        query_type = GraphQL::ObjectType.define do
          name "Query"
          field :something, interface
        end

        assert_raises(NotImplementedError) {
          GraphQL::Schema.define do
            query(query_type)
          end
        }
      end
    end
  end

  describe "object_from_id" do
    describe "when the hook wasn't implemented" do
      it "raises not implemented" do
        assert_raises(NotImplementedError) {
          empty_schema.object_from_id(nil, nil)
        }
      end
    end

    describe "when a schema is defined with a relay ID field, but no hook" do
      it "raises not implemented" do
        thing_type = GraphQL::ObjectType.define do
          name "Thing"
          global_id_field :id
        end

        query_type = GraphQL::ObjectType.define do
          name "Query"
          field :thing, thing_type
        end

        assert_raises(NotImplementedError) {
          GraphQL::Schema.define do
            query(query_type)
            resolve_type ->(obj, ctx) { :whatever }
          end
        }
      end
    end
  end

  describe "id_from_object" do
    describe "when the hook wasn't implemented" do
      it "raises not implemented" do
        assert_raises(NotImplementedError) {
          empty_schema.id_from_object(nil, nil, nil)
        }
      end
    end

    describe "when a schema is defined with a node field, but no hook" do
      it "raises not implemented" do
        query_type = GraphQL::ObjectType.define do
          name "Query"
          field :node, GraphQL::Relay::Node.field
        end

        assert_raises(NotImplementedError) {
          GraphQL::Schema.define do
            query(query_type)
            resolve_type ->(obj, ctx) { :whatever }
          end
        }
      end
    end
  end

  describe "#instrument" do
    class MultiplyInstrumenter
      def initialize(multiplier)
        @multiplier = multiplier
      end

      def instrument(type_defn, field_defn)
        # TODO: provide an api for wrapping resolve functions only
        # WITHOUT mutation -- if you mutate introspection fields,
        # you're gonna have a bad time!
        if type_defn.name == "Query" && field_defn.name == "int"
          prev_proc = field_defn.resolve_proc
          field_defn.resolve = ->(obj, args, ctx) {
            inner_value = prev_proc.call(obj, args, ctx)
            inner_value * @multiplier
          }
          field_defn
        end
      end
    end

    class VariableCountInstrumenter
      attr_reader :counts
      def initialize
        @counts = []
      end

      def before_query(query)
        @counts << query.variables.length
      end

      def after_query(query)
      end
    end

    let(:variable_counter) {
      VariableCountInstrumenter.new
    }
    let(:query_type) {
      GraphQL::ObjectType.define do
        name "Query"
        field :int, types.Int do
          argument :value, types.Int
          resolve -> (obj, args, ctx) { args[:value] }
        end
      end
    }

    let(:schema) {
      spec = self
      GraphQL::Schema.define do
        query(spec.query_type)
        instrument(:field, MultiplyInstrumenter.new(3))
        instrument(:query, spec.variable_counter)
      end
    }

    it "can modify field definitions" do
      res = schema.execute(" { int(value: 2) } ")
      assert_equal 6, res["data"]["int"]
    end

    it "can wrap query execution" do
      schema.execute("query getInt($val: Int = 5){ int(value: $val) } ")
      schema.execute("query getInt($val: Int = 5, $val2: Int = 3){ int(value: $val) int2: int(value: $val2) } ")
      assert_equal [1, 2], variable_counter.counts
    end
  end
end
