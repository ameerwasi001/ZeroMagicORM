module Constraints
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
    end

    class Unique
        def ==(other)
            return other.is_a? Unique
        end
        
        alias eql? ==

        def hash
            return "Unique".hash
        end

        def contradictions
            return Set.new []
        end

        def to_s
            return "UNIQUE"
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
    end
end