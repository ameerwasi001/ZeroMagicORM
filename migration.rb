require_relative 'tableDiff.rb'
require_relative 'connection.rb'
require_relative 'utils.rb'

class AddTable
    attr_accessor :tableName, :newDef

    def initialize(name, tableDef)
        @tableName = name
        @newDef = tableDef
    end

    def to_sql(ctx, platform)
        return @newDef.to_sql(ctx, platform)
    end
end

class ChangeTable
    attr_accessor :tableName, :changeTable, :newDef

    def initialize(name, changes, tableDef)
        @tableName = name
        @changeTable = changes
        @newDef = tableDef
    end

    def to_s
        res = ""
        for k, changes in @changeTable
            for change in changes
                res += k.to_s + ": " + change.to_s + "\n"
            end
        end
        return res
    end

    def to_sql(ctx, platform)
        arr = []
        for _, changes in @changeTable
            for change in changes
                arr.append(change.to_sql(ctx, platform))
            end
        end
        return arr.map{|x| "  " + x}.join(",\n") + ";"
    end
end

class Migration
    attr_accessor :tables

    def initialize(tableList)
        suchTables = {}
        for table in tableList
            suchTables[table.name] = table
        end
        @tables = suchTables
    end

    def contains?(key)
        return @tables.has_key?(key)
    end    

    def diff(newSchema)
        oldSchema = self
        entireChanges = {}
        for k, v in newSchema.tables
            u2 = v
            if oldSchema.contains?(k)
                u1 = oldSchema.tables[k]
                changeDict = {}
                for kChange, changes in tableDiff(u1, u2)
                    changeDict[kChange] = []
                    for change in changes
                        changeDict[kChange].append(change)
                    end
                end
                entireChanges[k] = ChangeTable.new(k, changeDict, u2)
            else
                entireChanges[k] = AddTable.new(k, u2)
            end
        end
        return entireChanges
    end

    def to_sql(newScheme, platform)
        changes = self.diff(newScheme)
        str = ""
        ctx = Context.new([], [])
        for k, v in changes
            if v.is_a? ChangeTable
                str += "ALTER TABLE " + k + "_ \n"
                str += v.to_sql(ctx, platform)
            else
                str += "CREATE TABLE " + k + "_ (\n" + indent(v.to_sql(ctx, platform)) + "\n);\n"
            end
        end
        return ctx.generate(str)
    end

    def migrate_to(dbAuth, newSchema, platform)
        sql = self.to_sql(newSchema, platform)
        pg_query(dbAuth, sql)
    end
end