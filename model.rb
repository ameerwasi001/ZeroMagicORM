require_relative 'inferModels.rb'
require_relative 'fields.rb'

class Record
    attr_accessor :name, :keys, :obj, :model, :saved

    def initialize(name, model, keys)
        @name = name
        @model = model
        @keys = Set.new
        @obj = {}
        @saved = false
        for k in keys
            if k != :id
                @obj[k] = nil
                @keys.add(k)
            end
        end
    end

    def [](index)
        return @obj[index]
    end

    def []=(index, val)
        if not @keys.include?(index)
            raise ArgumentError.new "'#{index}' not in record"
        end
        @obj[index] = val
    end

    def to_s
        strs = []
        for k, v in @obj
            if v == nil
                strs.append "#{k}: nil"
            else
                strs.append "#{k}: #{v}"
            end
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end

class Model
    attr_accessor :model, :name, :obj

    def initialize(name, schema)
        @name = name
        @model = {}
        schema_dict = schema.to_dict
        graph = createGraph(schema)
        relations = inferModel(graph)
        vertices = relations[name]
        v_dict = {}
        for x in vertices
            v_dict[x.reference] = x.is_singular ? x.reference : (x.reference + "s")
        end
        for v in vertices
            str = v_dict[v.reference].to_s.dup
            str[0] = str[0].downcase
            @model[str.to_sym] = schema_dict[v.reference.to_s]
        end
        for k, feild in schema_dict[self.name].table.obj
            if not feild.is_a? Fields::ForeignKeyField
                @model[k.to_sym] = feild
            end
        end
    end

    def instantiate
        set = Set.new
        for k, v in @model
            set.add(k)
        end
        return Record.new(self.name, self, set)
    end

    def to_s
        strs = []
        for k, v in @model
            strs.append "#{k}: #{v.class.name}"
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end