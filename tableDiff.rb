class Change
    attr_accessor :key, :newVal

    def initialize(key, new_value)
        @key = key
        @val = new_value
    end

    def to_s
        return "Change(" + @key.to_s + ", " + @val.to_s + ")"
    end
end

class Add
    attr_accessor :key, :val

    def initialize(key, val)
        @key = key
        @val = val
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

    def to_s
        return "Remove(" + @key.to_s + ")"
    end
end

class ChangeConstraints
    attr_accessor :key, :set

    def initialize(key, vals)
        @key = key
        @set = vals
    end

    def to_s
        vals = []
        for val in @set
            vals.append(val.to_s)
        end
        return "ChangeConstraints(" + @key.to_s + ", {" + vals.join(", ") + "})"
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
            changes.append(Add.new(k, v))
            changes.append(ChangeConstraints.new(k, newConstraints[k]))
        end
    end
    for k, k_constraints in oldConstraints
        new_k_constraints = newConstraints[k]
        if new_k_constraints != nil
            if k_constraints != new_k_constraints
                changes.append(ChangeConstraints.new(k, new_k_constraints))
            end
        end
    end
    return aggregateChanges(changes)
end