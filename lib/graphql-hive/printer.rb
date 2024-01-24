# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # - removes literals
    # - removes aliases
    # - sort nodes and directives (files, arguments, variables)
    class Printer < GraphQL::Language::Printer
      def print_node(node, indent: '')
        case node
        when Float, Integer
          print_string('0')
        when String
          print_string('')
        else
          super(node, indent: indent)
        end
      end

      def print_field(field, indent: '')
        print_string(indent)
        print_string(field.name)
        if field.arguments.any?
          print_string('(')
          field.arguments.sort_by(&:name).each_with_index do |a, i|
            print_argument(a)
            print_string(', ') if i < field.arguments.size - 1
          end
          print_string(')')
        end
        print_directives(field.directives)
        print_selections(field.selections, indent: indent)
      end

      def print_directives(directives)
        super(directives.sort_by(&:name))
      end

      def print_selections(selections, indent: '')
        sorted_nodes = selections.sort_by do |s|
          next s.name if s.respond_to?(:name)
          next s.type.name if s.respond_to?(:type)

          raise "don't know how to sort selection node: #{s.inspect}"
        end
        super(sorted_nodes, indent: indent)
      end

      def print_directive(directive)
        print_string('@')
        print_string(directive.name)

        if directive.arguments.any?
          print_string('(')
          directive.arguments.sort_by(&:name).each_with_index do |a, i|
            print_argument(a)
            print_string(', ') if i < directive.arguments.size - 1
          end
          print_string(')')
        end
      end

      def print_operation_definition(operation_definition, indent: '')
        print_string(indent)
        print_string(operation_definition.operation_type)
        if operation_definition.name
          print_string(' ')
          print_string(operation_definition.name)
        end

        if operation_definition.variables.any?
          print_string('(')
          operation_definition.variables.sort_by(&:name).each_with_index do |v, i|
            print_variable_definition(v)
            print_string(', ') if i < operation_definition.variables.size - 1
          end
          print_string(')')
        end

        print_directives(operation_definition.directives)
        print_selections(operation_definition.selections, indent: indent)
      end
    end
  end
end
