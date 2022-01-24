require 'set'
require_relative 'fields.rb'

Singular = Struct.new("Singular", :reference, :back_ref) do
    def is_singular
        return true
    end
end

Plural = Struct.new("Plural", :reference, :back_ref) do
    def is_singular
        return false
    end
end

def createGraph(schema)
    adjacencies = {}
    for table_name, table in schema.to_dict
        adjacencies[table_name] = {}
    end
    for table_name, table in schema.to_dict
        for k, field in table.table.obj
            if field.is_a? Fields::ForeignKeyField
                reference = field
                adjacencies[table_name][k] = reference
            end
        end
    end
    for table_name, adjacencies_name in adjacencies.clone
        table_adjacencies = {}
        for k, v in adjacencies[table_name]
            table_adjacencies[v] = Set.new
        end
        for k, v in adjacencies[table_name]
            table_adjacencies[v].add(k)
        end
        adjacencies[table_name] = [table_adjacencies, adjacencies[table_name]]
    end
    return adjacencies
end

def inferModel(graph)
    res = {}
    for k, vs in graph
        res[k] = {}
        for kx, vxs in vs[1]
            res[k][kx] = nil
        end
    end
    visited = Set.new
    for k, vs in graph
        dfsPoint(res, graph, visited, k)
    end
    newRes = {}
    for table_name, dict in res
        newDict = {}
        for k, v in dict
            newDict[k.to_s[0...-4].to_sym] = v
        end
        newRes[table_name] = newDict
    end
    return newRes
end

def dfsPoint(res, graph, visited, vertex)
    if visited.include?(vertex)
        return
    end
    visited.add(vertex)
    if not graph.has_key?(vertex)
        return
    end
    for k, v in graph[vertex][1]
        if graph.has_key?(v.reference) and graph[v.reference][0].include?(ForeignKeyField.new(reference: vertex))
            res[vertex][k] = Singular.new(v.reference, v.back_ref)
        else
            if res[v.reference].has_key?(v.back_ref)
                raise ArgumentError.new "Inference Error: Conflicting back references to #{v.reference}"
            end
            res[v.reference][v.back_ref] = Plural.new(vertex, v.back_ref)
            res[vertex][k] = Singular.new(v.reference, v.back_ref)
        end
        dfsPoint(res, graph, visited, v)
    end
end