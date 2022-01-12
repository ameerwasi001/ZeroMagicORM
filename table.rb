require 'json'
require_relative 'fields.rb'
include Fields
require_relative 'constraints.rb'
include Constraints
require_relative 'utils.rb'

module TableDefintion
    class DataTable
        attr_accessor :obj, :constraints, :defaults, :name

        def initialize
            @obj = {}
            @defaults = {}
            @constraints = {}
        end

        def set(key, val, constraints=nil)
            @obj[key] = val
            @constraints[key] = Set.new
            @defaults[key] = Set.new([NotNull.new])
            if constraints!=nil
                for constraint in constraints.to_a
                    self.constraint(key, [constraint])
                end
            end
        end

        def constraint(key, vals)
            @defaults[key] = @defaults[key].clear
            valsSet = Set.new(vals)
            union = @constraints[key] | valsSet
            for val in vals
                contraditions = union & val.contradictions
                if contraditions.length > 0
                    raise StandardError.new("Contradictory constraints {" + val.to_s + ", " + contraditions.to_a.join(", ") + "}")
                end
            end
            @constraints[key] = union
        end

        def defaultConstraint(key, vals)
            valsSet = Set.new(vals)
            union = @defaults[key] | valsSet
            for val in vals
                contraditions = union & val.contradictions
                if contraditions.length > 0
                    raise StandardError.new("Contradictory constraints {" + val.to_s + ", " + contraditions.to_a.join(", ") + "}")
                end
            end
            @defaults[key] = union
        end

        def []=(key, val)
            return self.set(key, val, val._constraints)
        end

        def to_sql(ctx, platform)
            res = []
            for k, v in self.obj
                k_constraints = constraints[k]
                constraints = k_constraints.to_a.map{|x| x.to_sql(platform)}
                if Platforms::POSTGRES == platform and k_constraints.include?(Constraints::AutoIncrement.new)
                    rectified_constraints = constraints.select{|x| x != Constraints::AutoIncrement.new.to_sql(platform)}
                    seq_name = "#{self.name}__#{k.to_s}_seq"
                    create_seq(ctx, self.name, k, seq_name)
                    str = k.to_s + " " + v.to_sql(platform) + " " + rectified_constraints.map{|x| "CONSTRAINT #{constraint_name(self.name, k, x)} #{x}"}.join(" ") + " DEFAULT NEXTVAL('#{seq_name}')"
                    if k == :id
                        str += " PRIMARY KEY"
                    end
                    res.append(str)
                else
                    if k == :id and Platforms::SQLITE == platform
                        res.append(k.to_s + " INTEGER CONSTRAINT NOT NULL PRIMARY KEY")
                    else
                        res.append(k.to_s + " " + v.to_sql(platform) + " " + constraints.map{|x| "CONSTRAINT #{constraint_name(self.name, k, x)} #{x}"}.join(" "))
                    end
                end
            end
            return res.join(",\n")
        end

        def to_s()
            arr = []
            for k, v in @obj
                k_constraints = @constraints[k]
                k_defaults = @defaults[k]
                res = k.to_s() + ": " + v.to_s()
                if k_constraints.length == 0
                    res += " <- " + "{" + k_defaults.to_a.join(", ") + "}"
                else
                    res += " <- " + "{" + k_constraints.to_a.join(", ") + "}"
                end
                arr.push(res)
            end
            if @name == ""
                raise StandardError.new(@name + " is not set")
            end
            return @name.to_s() + "{" + arr.join(", ") + "}"
        end
    end

    class Table
        attr_accessor :table

        def initialize()
            @table = DataTable.new()
            @table[:id] = IntField.new(field_type: IntTypes::Big)
            @table.defaultConstraint(:id, [NotNull.new(), AutoIncrement.new()])
            self.create()
            for k, constraint in @table.defaults
                @table.constraints[k] = @table.constraints[k] | @table.defaults[k]
            end
        end

        def set_name(value)
            @table.name = value
        end

        def name=(value)
            self.set_name(value)
        end

        def name
            return @table.name
        end

        def create()
        end

        def self.json_create(o)
            object = o["object"]
            constraints = o["constraints"]
            name = o["name"]
            this = new()
            this.name = name
            this.table.obj = {}
            this.table.constraints = {}
            for k, field in object
                this.table.obj[k.to_sym] = Fields::fieldMap[field["json_class"]].json_create(field)
            end
            for k, k_constraints in constraints
                this.table.constraints[k.to_sym] = Set.new
                for k_constraint in k_constraints
                    k_real_constraint = Constraints::fieldMap[k_constraint["json_class"]].json_create(k_constraint)
                    this.table.constraints[k.to_sym].add(k_real_constraint)
                end
            end
            return this
        end

        def to_sql(ctx, platform)
            self.table.to_sql(ctx, platform)
        end

        def to_json(*args)
            constraints = {}
            for k, constraint in @table.constraints
                constraints[k] = []
            end
            for k, k_constraints in @table.constraints
                for k_constraint in k_constraints
                    constraints[k].append(k_constraint)
                end
            end
            return { 'json_class' => self.class.name, "name" => self.name, 'object' => @table.obj, "constraints" =>  constraints}.to_json(*args)
        end

        def to_s()
            return @table.to_s()
        end
    end
end