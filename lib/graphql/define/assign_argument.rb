module GraphQL
  module Define
    # Turn argument configs into a {GraphQL::Argument}.
    module AssignArgument
      def self.call(target, name, type = nil, description = nil, default_value: nil, &block)
        argument = if block_given?
          GraphQL::Argument.define(&block)
        else
          GraphQL::Argument.new
        end
        argument.name = name.to_s
        type && argument.type = type
        description && argument.description = description
        !default_value.nil? && argument.default_value = default_value

        target.arguments[name.to_s] = argument
      end
    end
  end
end
