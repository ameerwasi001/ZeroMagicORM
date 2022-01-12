require_relative 'table.rb'
require_relative "constraints.rb"
require_relative 'platforms.rb'

class Change
    attr_accessor :key, :newVal

    def initialize(key, new_value)
        @key = key
        @val = new_value
    end

    def to_sql(ctx, platform)
        if platform == Platforms::POSTGRES
            return "ALTER COLUMN " + @key.to_s + " TYPE " + @val.to_sql(platform)
        else
            unsupported_platform(platform)
        end
    end

    def to_s
        return "Change(" + @key.to_s + ", " + @val.to_s + ")"
    end
end

class Add
    attr_accessor :key, :val, :table_name, :constraints

    def initialize(table_name, key, val, constraints=nil)
        @key = key
        @val = val
        @constraints = constraints
        @table_name = table_name
    end

    def to_sql(ctx, platform)
        if platform == Platforms::POSTGRES
            string_constraints = []
            for constraint in @constraints
                if constraint.is_a? Constraints::AutoIncrement
                    seq_name = "#{@table_name}__#{@key.to_s}_seq"
                    create_seq(ctx, @table_name, @key, seq_name)
                    string_constraints.append("DEFAULT NEXTVAL('#{seq_name}')")
                else
                    string_constraints.append(constraint.to_sql(platform))
                end
            end
            return "ADD COLUMN " + @key.to_s + " " + @val.to_sql(platform) + " " + string_constraints.join(" ")
        else
            unsupported_platform(platform)
        end
    end

    def to_s
        return "Add(" + @key.to_s + ", " + @val.to_s + ")"
    end
end

class Remove
    attr_accessor :key

    def initialize(key)
        @key = key
    end

    def to_sql(ctx, platform)
        if platform == Platforms::POSTGRES
            return "DROP COLUMN " + @key.to_s
        else
            unsupported_platform(platform)
        end
    end

    def to_s
        return "Remove(" + @key.to_s + ")"
    end
end

class AddConstraint
    attr_accessor :key, :constraint, :table_name

    def initialize(name, key, constraint)
        @key = key
        @constraint = constraint
        @table_name = name
    end

    def to_sql(ctx, platform)
        if platform == Platforms::POSTGRES
            return @constraint.add_constraint_sql(ctx, platform, @table_name, @key)
        else
            unsupported_platform(platform)
        end
    end

    def to_s
        return "AddConstraint(" + @key.to_s + "," + @constraint.to_s + ")"
    end
end

class RemoveConstraint
    attr_accessor :key, :constraint, :table_name

    def initialize(name, key, constraint)
        @key = key
        @constraint = constraint
        @table_name = name
    end

    def to_sql(ctx, platform)
        if platform == Platforms::POSTGRES
            return @constraint.remove_constraint_sql(ctx, platform, @table_name, @key)
        else
            unsupported_platform(platform)
        end
    end

    def to_s
        return "RemoveConstraint(" + @key.to_s + "," + @constraint.to_s + ")"
    end
end

def aggregateChanges(changes)
    changeDict = {}
    for change in changes
        k = change.key
        if changeDict.include?(k)
            changeDict[k] = changeDict[k] + [change]
        else
            changeDict[k] = [change]
        end
    end
    return changeDict
end

def tableDiff(oldObj, newObj)
    oldFields = oldObj.table.obj
    newFields = newObj.table.obj
    oldConstraints = oldObj.table.constraints
    newConstraints = newObj.table.constraints
    name = newObj.name
    changes = []
    for k, v in oldFields
        if newFields.include?(k)
            if newFields[k] != oldFields[k]
                changes.append(Change.new(k, newFields[k]))
            end
        else
            changes.append(Remove.new(k))
        end
    end
    for k, v in newFields
        if not oldFields.include?(k)
            changes.append(Add.new(name, k, v, newConstraints[k]))
        end
    end
    for k, k_constraints in oldConstraints
        new_k_constraints = newConstraints[k]
        if new_k_constraints != nil
            for new_k_constraint in new_k_constraints
                if not k_constraints.include?(new_k_constraint)
                    changes.append(AddConstraint.new(name, k, new_k_constraint))
                end
            end
            for old_k_constraint in k_constraints
                if not new_k_constraints.include?(old_k_constraint)
                    changes.append(RemoveConstraint.new(name, k, old_k_constraint))
                end
            end
        end
    end
    return aggregateChanges(changes)
end

def printDiffs(difference)
    for k, vs in difference
        for v in vs
            print k, ": ", v, "\n"
        end
    end
end