require 'set'
require_relative 'fields.rb'

Singular = Struct.new("Singular", :reference) do
    def is_singular
        return true
    end
end

Plural = Struct.new("Plural", :reference) do
    def is_singular
        return false
    end
end

def createGraph(schema)
    adjacencies = {}
    for table_name, table in schema.to_dict
        adjacencies[table_name] = Set.new
    end
    for table_name, table in schema.to_dict
        for k, field in table.table.obj
            if field.is_a? Fields::ForeignKeyField
                adjacencies[table_name].add(field.reference)
            end
        end
    end
    return adjacencies
end

def inferModel(graph)
    res = {}
    for k, _ in graph
        res[k] = Set.new
    end
    visited = Set.new
    for k, vs in graph
        dfsPoint(res, graph, visited, k)
    end
    return res
end

def dfsPoint(res, graph, visited, vertex)
    if visited.include?(vertex)
        return
    end
    visited.add(vertex)
    if not graph.has_key?(vertex)
        return
    end
    for v in graph[vertex]
        if graph.has_key?(v) and graph[v].include?(vertex)
            res[vertex].add(Singular.new(v))
        else
            res[v].add(Plural.new(vertex))
            res[vertex].add(Singular.new(v))
        end
        dfsPoint(res, graph, visited, v)
    end
end