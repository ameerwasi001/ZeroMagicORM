require_relative 'inferModels.rb'
require_relative 'fields.rb'
require_relative 'utils.rb'
require_relative 'query.rb'

Absolute = Struct.new("Absolute", :value) do
    def is_absolute?
        return true
    end

    def to_sql(table_name)
        self.value.to_s
    end
end

Relative = Struct.new("Relative", :value) do
    def is_absolute?
        return false
    end

    def to_sql(table_name)
        return "(select currval('#{table_name}__id_seq')) - #{self.value.to_s}"
    end
end

class Collection
    attr_accessor :collection_internal, :model, :query

    def initialize(collection, model)
        self.collection = collection
        @model = model
    end

    def banish_collection
        @collection_internal = nil
    end

    def collection=(val)
        @collection_internal = val
    end

    def collection
        if @collection_internal == nil and @query != nil
            conn = DBConn.getConnection
            @collection_internal = conn.exec @query.to_sql
        end
        return @collection_internal
    end

    def where(obj)
        self.banish_collection
        @query.where(obj)
        return self
    end

    def self.from_query(query, model)
        this = new(nil, model)
        this.query = query
        return this
    end

    def instantiate(obj)
        instance = @model.instantiate
        instance.dangerously_set_field(:id, obj["id"])
        for k, v in obj
            model_key = k.to_s[0...-4]
            model_key_sym = model_key.to_sym
            if k.to_s.end_with?("__id") and @model.schema.relations[@model.name].has_key?(model_key_sym)
                instance.dangerously_set_field(model_key_sym, v)
            else
                instance.dangerously_set_field(k, v)
            end
        end
        instance.saved = true
        return instance
    end

    def each
        for obj in self.collection
            yield self.instantiate(obj)
        end
    end

    def first
        for obj in self
            return obj
        end
    end
end

class Record
    attr_accessor :name, :keys, :obj, :model, :readonly_keys, :autoincrement_keys, :singulars, :saved

    def initialize(name, model, keys, readonly_keys, autoincrement_keys, singulars)
        @name = name
        @singulars = singulars
        @autoincrement_keys = autoincrement_keys
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
        if @saved and ((not @obj.has_key?(index)) or @obj[index].is_a?(Integer)) and (not @autoincrement_keys.include?(index))
            if not @model.model.has_key?(index)
                raise ArgumentError.new "No key named '#{index}' is present in #{@model.name}"
            end
            modelObj = @model.model[index]
            tableName = modelObj.name
            new_model = Model.new(tableName, @model.schema)
            if @singulars.include?(index)
                id = @obj[index.to_sym]
                query = Query.new(new_model).where({id: id}).limit(1)
                record = Collection.from_query(query, new_model).first
                @obj[index] = record
                return record
            else
                back_ref = new_model.back_refs[index.to_s[0...-1] + "__id"]
                id = @obj[:id]
                dict = {}
                dict[back_ref.to_sym] = id
                query = Query.new(new_model).where(dict)
                collection = Collection.from_query(query, new_model)
                @obj[index] = collection
                return collection
            end
        end
        if not @obj.has_key?(index)
            raise ArgumentError.new "No field named '#{index}' yet exists"
        end
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
                if v.is_a?(Record) and v.name == dbObj.name
                    validated[v] = v
                    if validated.include?(v)
                        next
                    end
                    v.validate_single(validated)
                    next
                end
                raise ArgumentError.new "#{v} is not a valid object of #{dbObj.class.name}"
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

    def dangerously_set_field(key, val)
        @obj[key.to_sym] = val
    end

    def save
        self.validate
        inserts, updates = self.to_sql
        conn = DBConn.getConnection
        conn.exec "BEGIN;"
        for tup in inserts
            obj, returns, insert = tup
            res = conn.exec(insert + ";")
            for row in res
                break
            end
            for return_ in returns
                value = row[return_.to_s.downcase]
                obj.dangerously_set_field(return_, value)
            end
        end
        for update in updates
            conn.exec(update + ";")
        end
        conn.exec "COMMIT;"
        self.mark_saved
    end

    def to_sql
        generated = {}.compare_by_identity
        statements = []
        deps = {}
        offsets = {}
        updates = []
        inserts = self.to_sql_singleton({}, updates, offsets, deps, statements, generated)
        complete_insertion_updates = self.to_sql_update(offsets, deps, generated)
        updates += complete_insertion_updates
        return statements, updates
    end

    def to_sql_update(offsets, deps, generated)
        updates = []
        for table, dep in deps
            sets = Set.new
            for k, model in dep
                sets.add(k.to_s + "__id = #{offsets[model].to_sql(model.name)}")
            end
            offset = offsets[table]
            if sets.length > 0
                updates.append "UPDATE #{table.name}_ SET #{sets.to_a.join(", ")} WHERE id = #{offset.to_sql(table.name)}"
            end
        end
        return updates
    end

    def to_sql_singleton(inserts, updates, offsets, deps, statements, generated)
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
        returns_arr = @autoincrement_keys.to_a
        to_generates = {}
        for key, field in @obj
            if @singulars.include?(key)
                names_arr.append((key.to_s + "__id").to_sym)
                if field.is_a? Record
                    to_generates[key] = field
                    vals_arr.append("NULL")
                else
                    vals_arr.append("#{field}")
                end
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
        if @saved
            assignments = names_arr.zip(vals_arr).map{|xs| xs[0].to_s + " = " + xs[1].to_s}.join(", ")
            id = @obj[:id]
            updates.append("UPDATE #{@name}_ SET #{assignments} WHERE id = #{id}")
            offsets[self] = Absolute.new id
        else
            names = names_arr.join(", ")
            vals = vals_arr.join(", ")
            returns = returns_arr.join(", ")
            statements.append([self, returns_arr, "INSERT INTO #{@name}_ (#{names}) VALUES (#{vals}) RETURNING #{returns}"])
            if inserts.has_key? self.name
                inserts[self.name] += 1
            else
                inserts[self.name] = 0
            end
            offsets[self] = Relative.new inserts[self.name]
        end
        for k, to_generate in to_generates
            to_generate.to_sql_singleton(inserts, updates, offsets, deps, statements, generated)
        end
        deps[self] = to_generates
        return inserts
    end
end

class Model
    attr_accessor :model, :name, :obj, :readonly_fields, :singulars, :schema, :back_refs

    def initialize(name, schema)
        @name = name
        @readonly_fields = Set.new [:id]
        @auto_increment_fields = Set.new [:id]
        @model = {}
        @schema = schema
        schema_dict = schema.to_dict
        graph = schema.graph
        relations = schema.relations
        vertices = relations[name]
        @singulars = Set.new
        @back_refs = {}
        for k, v in schema.graph[name][1]
            @back_refs[v.back_ref] = k
        end
        for k, v in vertices
            if v.is_singular
                @singulars.add(k)
                @model[k] = schema_dict[v.reference]
            else
                @model[(k.to_s + "s").to_sym] = schema_dict[v.reference]
            end
        end
        for k, feild in schema_dict[self.name].table.obj
            if not feild.is_a? Fields::ForeignKeyField
                constraints = schema_dict[self.name].table.constraints
                @model[k.to_sym] = feild.get_value(constraints[k])
                if constraints[k].include?(Constraints::AutoIncrement.new)
                    @readonly_fields.add(k.to_sym)
                    @auto_increment_fields.add(k.to_sym)
                end
            end
        end
    end

    def instantiate
        set = Set.new
        for k, v in @model
            set.add(k)
        end
        return Record.new(self.name, self, set, @readonly_fields, @auto_increment_fields, @singulars)
    end

    def to_s
        strs = []
        for k, v in @model
            strs.append "#{k}: #{v.name}"
        end
        return @name + "{" + strs.join(", ") + "}"
    end
end