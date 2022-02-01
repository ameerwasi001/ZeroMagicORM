require_relative 'table.rb'

class Query
    attr_accessor :limit_var, :clauses, :ordered_by, :model

    def initialize(model)
        @model = model.is_a?(TableDefintion::Table) ? model.init.model : model
        @clauses = {}
    end

    def is_valid(k, v)
        if @model.model.keys.include?(k) and (not @model.singulars.include?(k.to_sym))
            return @model.model[k].validator.validate(v)
        end
        if (@model.singulars.include?(k[0...-4].to_sym) and k.to_s.end_with?("__id")) or @model.singulars.include?(k.to_sym)
            return (v.is_a?(Integer) or v.is_a?(Record))
        end
        return false
    end

    def where(dict)
        for k, v in dict
            if not self.is_valid(k, v)
                raise "Invalid key-value pair (#{k}, #{v}) for #{model.name}"
            end
            @clauses[k] = v
        end
        return self
    end

    def limit(n)
        @limit_var = n
        return self
    end

    def order_by(by, desc)
        keys = Set.new(@model.schema.to_dict[@model.name].table.obj.keys)
        if (not @model.foreign_keys.include?(by.to_s[0...-4].to_sym)) and keys.include?(by.to_sym)
            @ordered_by = by
            @order_mode = desc ? "DESC" : "ASC"
            return self
        end
        raise ArgumentError.new "Can only be ordered by non-foreign-key attributes, not '#{by}'"
    end

    def to_sql
        initial = "SELECT * FROM #{@model.name}_ "
        clauses_arr = []
        for k, v in @clauses
            if v.is_a? Record
                clauses_arr.append("#{k}__id = #{v[:id]}")
            elsif @model.singulars.include?(k)
                clauses_arr.append("#{k}__id = #{v}")
            else
                clauses_arr.append("#{k} = #{v}")
            end
        end
        if @clauses.length > 0
            initial += "WHERE #{clauses_arr.join(" AND ")} "
        end
        if @limit_var != nil
            initial += "LIMIT #{@limit_var.to_s} "
        end
        if @ordered_by != nil
            initial += "ORDER BY #{@model.name}_.#{@ordered_by} #{@order_mode} "
        end
        return "#{initial};"
    end
end