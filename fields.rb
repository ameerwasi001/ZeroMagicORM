require 'set'
require 'json'
require_relative 'constraints.rb'

module Fields
    attr_accessor :fieldMap
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

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => {"field_type" => @field_type} }.to_json(*a)
        end

        def self.json_create(o)
            data = o['data']
            new(field_type: data["field_type"])
        end

        def to_sql(ctx, tb_name, field, platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def defaults
            Set.new [Constraints::NotNull.new]
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

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => {"max_length" => @max_length} }.to_json(*a)
        end

        def self.json_create(o)
            data = o['data']
            new(max_length: data["max_length"])
        end

        def to_sql(ctx, tb_name, field, platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def defaults
            Set.new [Constraints::NotNull.new]
        end

        def to_s
            return "VARCHAR(" + @max_length.to_s + ")"
        end
    end

    class ForeignKeyField
        attr_accessor :reference, :_constraints

        def initialize(reference: nil, constraints: nil)
            if constraints == nil
                constraints = Set.new
            end
            if reference == nil
                raise ArgumentError.new("Reference is required")
            end
            @_constraints = constraints
            @reference = reference
        end

        def ==(other)
            if not other.is_a?(ForeignKeyField) 
                return false 
            end
            if @reference != other.reference
                return false 
            end
            return true
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => {"reference" => @reference} }.to_json(*a)
        end

        def self.json_create(o)
            data = o["data"]
            new(reference: data["reference"])
        end

        def to_sql(ctx, tb_name, field, platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                ctx.add_end("ALTER TABLE #{tb_name}_ ADD CONSTRAINT \"#{tb_name}__#{@reference}__fk\" FOREIGN KEY (#{field}) REFERENCES #{@reference}_(id) ON DELETE CASCADE")
                return "BIGINT"
            else
                unsupported_platform(platform)
            end
        end

        def defaults
            Set.new [Constraints::Nullable.new]
        end

        def to_s
            return "Reference(" + @reference.to_s + ", cascade)"
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

        def self.json_create(o)
            data = o['data']
            new(max_length: data["max_length"])
        end

        def defaults
            Set.new [Constraints::NotNull.new]
        end

        def to_sql(ctx, tb_name, field, platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => {"max_length" => @max_length} }.to_json(*a)
        end
    end

    @fieldMap = {
        "Fields::IntField" => IntField,
        "Fields::CharField" => CharField,
        "Fields::TextField" => TextField,
        "Fields::ForeignKeyField" => ForeignKeyField,
    }
end