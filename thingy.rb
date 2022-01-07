require 'set'
require 'json'

require_relative 'fields.rb'
include Fields
require_relative 'table.rb'
include TableDefintion
require_relative 'tableDiff.rb'
require_relative 'migration.rb'

class User < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:username] = CharField.new(max_length: 128, constraints: [Unique.new, AutoIncrement.new])
        @table[:password] = CharField.new(max_length: 255)
        @table[:bio] = TextField.new(constraints: [Nullable.new])
    end
end

class User2 < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:username] = CharField.new(max_length: 255)
        @table[:password] = CharField.new(max_length: 255, constraints: [Nullable.new])
        @table[:phone_number] = IntField.new(field_type: IntTypes::Big)
    end
end

obj = JSON.dump(User.new)
such = Table.json_create(JSON.parse(obj))

difference = Migration.new([such]).diff(Migration.new([User2.new]))

printDiffs(difference)