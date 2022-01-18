require_relative 'inferModels.rb'
require_relative 'fields.rb'

class Record
    attr_accessor :name, :keys, :obj, :model, :readonly_keys, :saved

    def initialize(name, model, keys, readonly_keys)
        @name = name
        @readonly_keys = readonly_keys
        @model = model
        @keys = Set.new
        @obj = {}
        @saved = false
        for k in keys
            @keys.add(k)
        end
    end

    def [](index)
        return @obj[index]
    end

    def []=(index, val)
        if @readonly_keys.include?(index)
            raise ArgumentError.new "'#{index}' is a read-only field record"
        end
        if not @keys.include?(index)
            raise ArgumentError.new "'#{index}' not in record"
        end
        @obj[index] = val
    end

    def validate
        validated = {}.compare_by_identity
        self.validate_single(validated)
    end

    def validate_single(validated)
        for k in @keys
            if (not @obj.has_key?(k)) and @model.model[k].is_a? DBValue::DBValue and @model.model[k].is_required? and (not readonly_keys.include?(k))
                raise ArgumentError.new "'#{k}' is a required value"
            end
        end

        for k, v in @obj
            dbObj = @model.model[k]
            if dbObj.is_a? DBValue::DBValue then
                if not dbObj.validator.validate(v)
                    v_str = v == nil ? "nil" : v.class.name
                    raise ArgumentError.new "#{v_str} is not a valid #{dbObj.name}"
                end                
            else
                if v == nil 
                    next
                end
                if v.is_a? Integer
                    next
                end
                if v.name == dbObj.name
                    validated[v] = v
                    if validated.include?(v)
                        next
                    end
                    v.validate_single(validated)
                    next
                end
                raise ArgumentError.new "#{v.name} is not a valid object of #{dbObj.class.name}"
            end
        end
    end

    def to_s
        strs = []
        for k, v in @obj
            if v == nil
                strs.append "#{k}: nil"
            elsif v.is_a? Record
                strs.append "#{k}: #{v.name}"
            else
                strs.append "#{k}: #{v}"
            end
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end

class Model
    attr_accessor :model, :name, :obj, :readonly_fields

    def initialize(name, schema)
        @name = name
        @readonly_fields = Set.new [:id]
        @model = {}
        schema_dict = schema.to_dict
        graph = createGraph(schema)
        relations = inferModel(graph)
        vertices = relations[name]
        v_dict = {}
        for x in vertices
            if x.is_singular
                v_dict[x.reference] = x.reference
            else
                v_dict[x.reference] = x.reference + "s"
            end
        end
        for v in vertices
            str = v_dict[v.reference].to_s.dup
            str[0] = str[0].downcase
            @model[str.to_sym] = v.is_singular ? schema_dict[v.reference.to_s] : schema_dict[v.reference.to_s]
            if not v.is_singular
                @readonly_fields.add(str.to_sym)
            end
        end
        for k, feild in schema_dict[self.name].table.obj
            if not feild.is_a? Fields::ForeignKeyField
                constraints = schema_dict[self.name].table.constraints
                @model[k.to_sym] = feild.get_value(constraints[k])
            end
        end
    end

    def instantiate
        set = Set.new
        for k, v in @model
            set.add(k)
        end
        return Record.new(self.name, self, set, @readonly_fields)
    end

    def to_s
        strs = []
        for k, v in @model
            strs.append "#{k}: #{v.name}"
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end