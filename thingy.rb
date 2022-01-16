require 'set'
require 'json'

require_relative 'fields.rb'
include Fields
require_relative 'table.rb'
include TableDefintion
require_relative 'tableDiff.rb'
require_relative 'migration.rb'
require_relative 'platforms.rb'
require_relative 'schema.rb'

class User < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:profile] = ForeignKeyField.new(reference: "Profile")
        @table[:username] = CharField.new(max_length: 128, constraints: [Unique.new])
        @table[:password] = CharField.new(max_length: 255)
        @table[:bio] = TextField.new(constraints: [Nullable.new])
    end
end

class User2 < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:profile] = ForeignKeyField.new(reference: "Profile")
        @table[:username] = CharField.new(max_length: 255)
        @table[:password] = CharField.new(max_length: 255, constraints: [Nullable.new])
        @table[:phone_number] = IntField.new(field_type: IntTypes::Big, constraints: [Unique.new, AutoIncrement.new])
    end
end

class Post < Table
    attr_accessor :table

    def create
        self.name = "Post"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end

class Profile < Table
    attr_accessor :table

    def create
        self.name = "Profile"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end

dbAuth = DBAuth.new("localhost", 5432, "orm_test", "postgres", "root")
Users = User2.new
Profiles = Profile.new
Posts = Post.new
schema = Schema.new([])
schema.register(Users)
schema.register(Profiles)
schema.register(Posts)

schema.initialize_model

usr_migrations = Migrations.new("usr")
usr_migrations.migrate(dbAuth, schema, Platforms::POSTGRES)

print Users.model, "\n"
print Posts.model, "\n"
print Profiles.model, "\n"