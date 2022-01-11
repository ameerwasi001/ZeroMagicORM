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