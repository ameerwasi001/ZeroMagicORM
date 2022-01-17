require_relative 'platforms.rb'

module Constraints
    attr_accessor :fieldMap

    class Nullable
        def ==(other)
            return other.is_a? Nullable
        end
        
        alias eql? ==
        
        def hash
            return "Nullable".hash
        end

        def contradictions
            return Set.new [NotNull.new()]
        end

        def to_s
            return "NULL"
        end

        def to_sql(platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def add_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ALTER COLUMN " + column.to_s + " DROP NOT NULL"
            else
                unsupported_platform(platform)
            end
        end

        def remove_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ALTER COLUMN " + column.to_s + " SET NOT NULL"
            else
                unsupported_platform(platform)
            end
        end

        def validator
            return Validator::TrueValidator.new
        end

        def self.json_create(o)
            new(*o['data'])
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => [] }.to_json(*a)
        end
    end

    class NotNull
        def ==(other)
            return other.is_a? NotNull
        end
        
        alias eql? ==
        
        def hash
            return "NotNull".hash
        end

        def contradictions
            return Set.new [Nullable.new()]
        end

        def to_s
            return "NOT NULL"
        end

        def to_sql(platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def add_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ALTER COLUMN " + column.to_s + " SET NOT NULL"
            else
                unsupported_platform(platform)
            end
        end

        def remove_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ALTER COLUMN " + column.to_s + " DROP NOT NULL"
            else
                unsupported_platform(platform)
            end
        end

        def validator
            return Validator::NotNullValidator.new
        end

        def self.json_create(o)
            new(*o['data'])
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => [] }.to_json(*a)
        end
    end

    class Unique
        def ==(other)
            return other.is_a? Unique
        end

        alias eql? ==

        def to_sql(platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def hash
            return "UNIQUE".hash
        end

        def contradictions
            return Set.new []
        end

        def to_s
            return "UNIQUE"
        end

        def to_sql(platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return self.to_s
            else
                unsupported_platform(platform)
            end
        end

        def add_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ADD CONSTRAINT " + constraint_name(table_name, column.to_s, self.to_sql(platform)) + " UNIQUE (" + column.to_s + ")"
            else
                unsupported_platform(platform)
            end
        end

        def remove_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "DROP CONSTRAINT " + constraint_name(table_name, column.to_s, self.to_sql(platform))
            else
                unsupported_platform(platform)
            end
        end

        def validator
            return Validator::TrueValidator.new
        end

        def self.json_create(o)
            new(*o['data'])
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => [] }.to_json(*a)
        end
    end

    class AutoIncrement
        def ==(other)
            return other.is_a? AutoIncrement
        end

        alias eql? ==

        def hash
            return "AutoIncrement".hash
        end

        def contradictions
            return Set.new []
        end

        def to_s
            return "AUTO INCREMENT"
        end

        def to_sql(platform)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "AUTO INCREMENT"
            else
                unsupported_platform(platform)
            end
        end

        def add_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                ctx.add_start("CREATE SEQUENCE #{@table_name}__#{@key.to_s}_seq")
                ctx.add_end("ALTER SEQUENCE #{@table_name}__#{@key.to_s}_seq OWNED BY #{@table_name}_.#{@key.to_s}")
                return "ALTER COLUMN " + column.to_s + " SET DEFAULT NEXTVAL('#{table_name}__#{column.to_s}_seq')"
            else
                unsupported_platform(platform)
            end
        end

        def remove_constraint_sql(ctx, platform, table_name, column)
            if platform == Platforms::SQLITE or platform == Platforms::POSTGRES
                return "ALTER COLUMN " + column.to_s + " SET DEFAULT(0)"
            else
                unsupported_platform(platform)
            end
        end

        def validator
            return Validator::TrueValidator.new
        end

        def self.json_create(o)
            new(*o['data'])
        end

        def to_json(*a)
            { 'json_class' => self.class.name, 'data' => [] }.to_json(*a)
        end
    end

    @fieldMap = {
        "Constraints::Nullable" => Nullable,
        "Constraints::NotNull" => NotNull,
        "Constraints::AutoIncrement" => AutoIncrement,
        "Constraints::Unique" => Unique,
    }
end