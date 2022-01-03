require 'set'

module Fields
    module IntTypes
        Tiny = "TINY"
        Small = "SMALL"
        Big = "BIG"

        Types = Set.new([Tiny, Small, Big])
    end

    class IntField
        attr_accessor :field_type, :_constraints

        def initialize(field_type: "", constraints: nil)
            if field_type!="" and not Fields::IntTypes::Types.include?(field_type)
                raise StandardError.new(field_type + " is not a valid integer type")
            end
            if constraints == nil
                constraints = Set.new
            end
            @_constraints = constraints
            @field_type = field_type
        end

        def ==(other)
            if not other.is_a?(IntField) 
                return false 
            end
            if @field_type != other.field_type 
                return false 
            end
            return true
        end

        def to_s
            return @field_type + "INT"
        end
    end

    class CharField
        attr_accessor :max_length, :_constraints

        def initialize(max_length: 255, constraints: nil)
            if constraints == nil
                constraints = Set.new
            end
            @_constraints = constraints
            @max_length = max_length
        end

        def ==(other)
            if not other.is_a?(CharField) 
                return false 
            end
            if @max_length != other.max_length 
                return false 
            end
            return true
        end

        def to_s
            return "VARCHAR(" + @max_length.to_s + ")"
        end
    end

    class TextField
        attr_accessor :max_length, :_constraints

        def initialize(max_length: nil, constraints: nil)
            if constraints == nil
                constraints = Set.new
            end
            @_constraints = constraints
            @max_length = max_length
        end

        def ==(other)
            if not other.is_a?(TextField) 
                return false 
            end
            if @max_length != other.max_length
                return false 
            end
            return true
        end

        def to_s
            if @max_length == nil
                return "TEXT"
            end
            return "TEXT(" + @max_length.to_s + ")"
        end
    end
end