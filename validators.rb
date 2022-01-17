module Validator

    class Validator
        def validate(t)
            return false
        end
    end

    class TrueValidator
        def validate(t)
            return true
        end
    end

    class NotNullValidator
        def validate(x)
            return x != nil
        end
    end

    class MaxLength < Validator
        attr_accessor :max_length

        def initialize(max_length)
            @max_length = max_length
        end

        def validate(xs)
            if xs == nil and (xs.is_a? String or xs.is_a? Integer)
                return true
            end
            if xs.is_a? String
                return xs.length <= @max_length
            elsif xs.is_a? Integer
                return xs <= @max_length
            end
            return false
        end
    end

    class IsString < Validator
        def validate(xs)
            return xs.is_a? String
        end
    end

    class IsInt < Validator
        def validate(xs)
            return xs.is_a? Integer
        end
    end

    class All < Validator
        attr_accessor :validators

        def initialize(validators)
            @validators = validators
        end

        def validate(x)
            for validator in @validators
                if not validator.validate(x)
                    return false
                end
            end
            return true
        end
    end

    class Any < Validator
        attr_accessor :validators

        def initialize(validators)
            @validators = validators
        end

        def validate(x)
            for validator in @validators
                if validator.validate(x)
                    return true
                end
            end
            return false
        end
    end

end