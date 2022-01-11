require_relative 'tableDiff.rb'
require_relative 'connection.rb'

def indent(str)
    arr = str.split("\n")
    i = 0
    while i < arr.length
        arr[i] = "  " + arr[i]
        i += 1
    end
    return arr.join("\n")
end

class AddTable
    attr_accessor :tableName, :newDef

    def initialize(name, tableDef)
        @tableName = name
        @newDef = tableDef
    end

    def to_sql(platform)
        return @newDef.to_sql(platform)
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

    def to_sql(platform)
        return @newDef.to_sql(platform)
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
        for k, v in changes
            if v.is_a? ChangeTable
                str += "ALTER TABLE " + k + "_ \n"
                arr = []
                for _, changes in v.changeTable
                    for change in changes
                        arr.append(change.to_sql(platform))
                    end
                end
                str += arr.map{|x| "  " + x}.join(",\n") + ";"
            else
                str += "CREATE TABLE " + k + "_ (\n" + indent(v.to_sql(platform)) + "\n);\n"
            end
        end
        return str
    end

    def migrate_to(dbAuth, newSchema, platform)
        sql = self.to_sql(newSchema, platform)
        pg_query(dbAuth, sql)
    end
end