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

  describe "#directives" do
    let(:schema) {
      query_type = GraphQL::ObjectType.define do
        name "Query"
        field :one, types.Int, resolve: -> (o,a,c) { 1 }
      end

      schema_directives = directives

      GraphQL::Schema.define do
        query(query_type)
        directives(schema_directives)
      end
    }

    describe "when @defer is not provided" do
      let(:directives) { [] }
      it "doesn't execute queries with defer" do
        res = schema.execute("{ one @defer }")
        assert_equal nil, res["data"]
        assert_equal 1, res["errors"].length
      end
    end

    describe "when @defer is provided" do
      let(:directives) { ["@defer"] }

      it "executes queries with defer" do
        res = schema.execute("{ one @defer, two: one }")
        # The deferred field is left out ??
        assert_equal({ "two" => 1 }, res["data"])
        assert_equal nil, res["errors"]
      end
    end
  end
end
