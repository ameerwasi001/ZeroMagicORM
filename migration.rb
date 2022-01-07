require_relative 'tableDiff.rb'

class Migration
    attr_accessor :tables

    def initialize(tableList)
        suchTables = {}
        for table in tableList
            suchTables[table.name] = table
        end
        @tables = suchTables
    end

    def diff(other)
        entireChanges = {}
        for k, v in @tables
            u1 = v
            u2 = other.tables[k]
            entireChanges[k] = {}
            for kChange, changes in tableDiff(u1, u2)
                entireChanges[k][kChange] = []
                for change in changes
                    entireChanges[k][kChange].append(change)
                end
            end
        end
        return entireChanges
    end
end