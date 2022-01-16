require_relative 'inferModels.rb'

class Model
    attr_accessor :model, :name

    def initialize(name, schema)
        @name = name
        @model = {}
        graph = createGraph(schema)
        relations = inferModel(graph)
        vertices = relations[name]
        v_dict = {}
        for x in vertices
            v_dict[x.reference] = x.is_singular ? x.reference : (x.reference + "s")
        end
        for v in vertices
            @model[v_dict[v.reference].to_sym] = schema.to_dict[v.reference.to_s]
        end
    end

    def to_s
        strs = []
        for k, v in @model
            strs.append "#{k}: #{v.name}"
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end