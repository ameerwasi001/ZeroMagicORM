require_relative 'inferModels.rb'
require_relative 'fields.rb'
require_relative 'utils.rb'

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

    def mark_saved
        if @saved
            return
        end
        @saved = true
        for k, field in @obj
            if field.is_a? Record
                field.mark_saved
            end
        end
    end

    def save(dbAuth)
        if @saved
            raise SystemCallError.new "Updates not implemented"
        else
            sql = self.to_sql
            self.mark_saved
        end
        conn = DBConn.getConnection
        conn.exec(sql)
    end

    def to_sql
        generated = {}.compare_by_identity
        statements = []
        deps = {}
        offsets = {}
        inserts = self.to_sql_singleton({}, offsets, deps, statements, generated)
        updates = self.to_sql_update(offsets, deps, statements, generated)
        return (["BEGIN"] + statements).join(";\n") + ";\n\n" + (updates + ["COMMIT"]).join(";\n") + ";"
    end

    def to_sql_update(offsets, deps, statements, generated)
        updates = []
        for table, dep in deps
            sets = Set.new
            for k, model in dep
                sets.add(k.to_s + "__id = (select currval('#{model.name}__id_seq')) - #{offsets[model]}")
            end
            offset = offsets[table]
            updates.append "UPDATE #{table.name}_ SET #{sets.to_a.join(", ")} WHERE id = (select currval('#{table.name}__id_seq')) - #{offset}"
        end
        return updates
    end

    def to_sql_singleton(inserts, offsets, deps, statements, generated)
        if generated.has_key?(self)
            return
        end
        generated[self] = self
        fields = {}
        for k, v in @obj
            if v.is_a? Record
                fields[k] = nil
            else
                fields[k] = v
            end
        end
        names_arr = []
        vals_arr = []
        to_generates = {}
        for key, field in @obj
            if field.is_a? Record
                names_arr.append((key.to_s + "__id").to_sym)
                to_generates[key] = field
                vals_arr.append("NULL")
            else
                names_arr.append(key.to_s)
                if field.is_a? String
                    val = "'#{fields[key].to_s}'"
                else
                    val = fields[key].to_s
                end
                vals_arr.append(val)
            end
        end
        names = names_arr.join(", ")
        vals = vals_arr.join(", ")
        statements.append("INSERT INTO #{@name}_ (#{names}) VALUES (#{vals}) RETURNING id")
        if inserts.has_key? self.name
            inserts[self.name] += 1
        else
            inserts[self.name] = 0
        end
        offsets[self] = inserts[self.name]
        for k, to_generate in to_generates
            to_generate.to_sql_singleton(inserts, offsets, deps, statements, generated)
        end
        deps[self] = to_generates
        return inserts
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
                if constraints[k].include?(Constraints::AutoIncrement.new)
                    @readonly_fields.add(k.to_sym)
                end
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