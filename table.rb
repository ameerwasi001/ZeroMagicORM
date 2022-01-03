require_relative 'fields.rb'
include Fields
require_relative 'constraints.rb'
include Constraints

module TableDefintion
    class DataTable
        attr_accessor :obj, :constraints, :defaults, :name

        def initialize
            @obj = {}
            @defaults = {}
            @constraints = {}
        end

        def set(key, val, constraints=nil)
            @obj[key] = val
            @constraints[key] = Set.new
            @defaults[key] = Set.new([NotNull.new])
            if constraints!=nil
                for constraint in constraints.to_a
                    self.constraint(key, [constraint])
                end
            end
        end

        def constraint(key, vals)
            @defaults[key] = @defaults[key].clear
            valsSet = Set.new(vals)
            union = @constraints[key] | valsSet
            for val in vals
                contraditions = union & val.contradictions
                if contraditions.length > 0
                    raise StandardError.new("Contradictory constraints {" + val.to_s + ", " + contraditions.to_a.join(", ") + "}")
                end
            end
            @constraints[key] = union
        end

        def defaultConstraint(key, vals)
            valsSet = Set.new(vals)
            union = @defaults[key] | valsSet
            for val in vals
                contraditions = union & val.contradictions
                if contraditions.length > 0
                    raise StandardError.new("Contradictory constraints {" + val.to_s + ", " + contraditions.to_a.join(", ") + "}")
                end
            end
            @defaults[key] = union
        end

        def []=(key, val)
            return self.set(key, val, val._constraints)
        end

        def to_s()
            arr = []
            for k, v in @obj
                k_constraints = @constraints[k]
                k_defaults = @defaults[k]
                res = k.to_s() + ": " + v.to_s()
                if k_constraints.length == 0
                    res += " <- " + "{" + k_defaults.to_a.join(", ") + "}"
                else
                    res += " <- " + "{" + k_constraints.to_a.join(", ") + "}"
                end
                arr.push(res)
            end
            if @name == ""
                raise StandardError.new(@name + " is not set")
            end
            return @name.to_s() + "{" + arr.join(", ") + "}"
        end
    end

    class Table
        attr_accessor :table

        def initialize()
            @table = DataTable.new()
            @table[:id] = IntField.new(field_type: IntTypes::Big)
            @table.defaultConstraint(:id, [NotNull.new(), AutoIncrement.new()])
            self.create()
            for k, constraint in @table.defaults
                @table.constraints[k] = @table.constraints[k] | @table.defaults[k]
            end
        end

        def set_name(value)
            @table.name = value
        end

        def name=(value)
            self.set_name(value)
        end

        def create()
        end

        def to_s()
            return @table.to_s()
        end
    end
end