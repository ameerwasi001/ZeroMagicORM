require 'sqlite3'
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

    def length
        return @changeTable.length
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
                if v.changeTable.length != 0
                    str += "ALTER TABLE " + k + "_ \n"
                    str += v.to_sql(ctx, platform)
                end
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

class Migrations
    attr_accessor :name, :db

    def initialize(name)
        @name = name
        @db = SQLite3::Database.new "migrations.db"
        db.execute "CREATE TABLE IF NOT EXISTS #{self.migration_name} (id INTEGER PRIMARY KEY AUTOINCREMENT, migration TEXT NOT NULL)"
    end

    def migration_name
        return "#{@name}_migrations"
    end

    def current_migration
        results = db.query "SELECT migration FROM #{self.migration_name} ORDER BY id DESC LIMIT 1"
        results.each do |row|
            migration = row[0]
            tables = JSON.parse(migration)
            classes = []
            for _, table in tables
                classes.append(Table.json_create(table))
            end
            return Migration.new(classes)
        end
        return Migration.new([])
    end

    def should_migrate(schema)
        for k, v in schema
            if v.is_a? AddTable
                return true
            end
        end
        for k, v in schema
            if v.length > 0
                return true
            end
        end
        return false
    end

    def migrate(dbAuth, newSchema, platform)
        migration = self.current_migration
        if self.should_migrate(migration.diff(Migration.new(newSchema)))
            migration.migrate_to(dbAuth, Migration.new(newSchema), platform)
            self.save(newSchema)
        end
    end

    def save(newSchema)
        tables = {}
        for table in newSchema
            tables[table.name] = table
        end
        jsonSchema = JSON.dump(tables)
        db.execute "INSERT INTO #{self.migration_name} (migration) VALUES ('#{jsonSchema}');"
    end
end