# ZeroMagicORM
ZeroMagicORM is a simple ORM with migrations. It currently only supports PostGreSQL but there are plans for support either MySQL, SQL Server, or both. The migration system internally uses SQLite to keep track of the databases in the JSON format, and all the migration in order to not require dynamic analysis of the schema.

## Migration system
For now, this is how classes for migrations are defined, even though there are plans to move away from class-based definitions.
```
class User < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:username] = CharField.new(max_length: 255)
        @table[:password] = CharField.new(max_length: 255, constraints: [Nullable.new])
        @table[:phone_number] = IntField.new(field_type: IntTypes::Big, constraints: [Unique.new])
    end
end
```
We first need to establish a connection with the database like such
```
dbAuth = DBAuth.new("localhost", 5432, "orm_test", "postgres", "root")
DBConn.create(dbAuth)
```
We must then register all the declared classes and initialize their models. Here's how you'd do that once you've created these classes.
```
Users = User.new

schema = Schema.new([])
schema.register(Users)
```
After all of this, one must initialize all the models.
```
schema.initialize_model
```
After that, all we have to do to migrate is, select a unique name for your project write this.
```
usr_migrations = Migrations.new("Your unique name")
usr_migrations.migrate(dbAuth, schema, Platforms::POSTGRES)
```
At this point, we are all done. Our schema is now migrated to our database.

## The model
A big part of this ORM is the inference of model, one does not need to define the model along with the schema. Defining the schema is the only thing that needs to be done and the model is inferred by just that. Here's how the model of the aforementioned schema looks.
```
User{id: BIGINT, username: VARCHAR(255), password: VARCHAR(255), phone_number: BIGINT}
```
This means that you can access id, username, password, and phone_number but you may only assign to the non-auto-increment fields and fields that do not reference multiple records. 

## Relationships
### One-To-Many
Relationships are the core of what models do, and how the inference of the system works. Before discussing all of that, we need to discuss one important field, the foreign key field. Here's how you define a foreign key field.
```
class Post < Table
    attr_accessor :table

    def create
        self.name = "Post"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end
```
The `reference` in this post should be equal to the name property of the classes we are trying to reference. It is also important to note that the order in which you declare you classes does not matter. In this case, the model for the post will be
```
Post{id: BIGINT, user: User, title: VARCHAR(500), text: TEXT}
```
as the user model becomes
```
User{id: BIGINT, posts: Post, username: VARCHAR(255), password: VARCHAR(255), phone_number: BIGINT}
```
Now since the `posts` fields in the "User" table references a list of values in "Post" table, it is a read-only field while the `user` field in the "Post" table is a writeable field.

## One-To-One
A classic example of a 1:1 relationship is the relationship that a user has with a profile. Here's how you encode that in this ORM.

```
class Profile < Table
    attr_accessor :table

    def create
        self.name = "Profile"
        @table[:user] = ForeignKeyField.new(reference: "User")
        @table[:title] = CharField.new(max_length: 500)
        @table[:text] = TextField.new(constraints: [Nullable.new])
    end
end

class User < Table
    attr_accessor :table

    def create
        self.name = "User"
        @table[:profile] = ForeignKeyField.new(reference: "Profile")
        @table[:username] = CharField.new(max_length: 255)
        @table[:password] = CharField.new(max_length: 255, constraints: [Nullable.new])
        @table[:phone_number] = IntField.new(field_type: IntTypes::Big, constraints: [Unique.new])
    end
end
```
Now, the user model becomes
```
User{profile: Profile, posts: Post, id: BIGINT, username: VARCHAR(255), password: VARCHAR(255), phone_number: BIGINT}
Profile{user: User, id: BIGINT, title: VARCHAR(500), text: TEXT}
```
Here both, `profile` field from the `User` table and the `user` field from the `Profile` table are writeable as well as readable. The key to making 1:1 relationships is to have both table reference each other.

### Many-To-Many
These M:N relationships complicates the matter a little bit since we need to provide back references manually. Here's how you would define a classic relationship such as a message relationship between two users.
```
class Message < Table
    attr_accessor :table

    def create
        self.name = "Message"
        @table[:sender] = ForeignKeyField.new(reference: "User", back_ref: "sent_message")
        @table[:text] = TextField.new
        @table[:receiver] = ForeignKeyField.new(reference: "User", back_ref: "received_message")
    end
end
```
The model for messages is now
```
Message{sender: User, receiver: User, id: BIGINT, text: TEXT}
```
while the model for the `User` evolves into
```
User{profile: Profile, posts: Post, sent_messages: Message, received_messages: Message, id: BIGINT, username: VARCHAR(255), password: VARCHAR(255), phone_number: BIGINT}
```
You see how all the new readonly fields are `"s"` appended to the back reference given by the programmer.

# Reading Data
There are two ways of reading data, one to retrieve something from the database based on an external factor, and the other to read related rows of the database. 

### The Query language
The first one is an extremely simplistic query language that is nothing but a thin layer of abstraction and validation over SQL and definitely could be more expressive.
```
users = Users.where({id: 1})
```
which returns a collection of `User`s that have the `id` of `1`. Here the more appropriate command is `get` since there can only ever be a single `User` with the `id` of `1`. Here's how you would write that more ergonomically.
```
user = Users.get({id: 1})
```

### Active Record Pattern
The active record pattern is the simplest way of accessing data and can be used for most fields and relationship oriented things. Lets see how that works.
```
title = user[:posts].first[:title]
```
This would give you the title of the first thing that this user has posted. All M:N and 1:N relationships return a collection while all 1:1 relationships return a single record. There's not much to say since this has mostly been covered under the models section.

## Insertion/Updates
Insertion and updates can be done simply by assigning to the record like this
```
post[:title] = "This post"
post[:text] = "Post Text"
post.save
```
This can be used either on a post that is retrieved from the database or one that has been initialized using
```
post = Posts.init
```
Assigning to the singular side of relationship can be done both ways depending on the data you have.
```
post[:user] = Users.get({id: 1})
```
or
```
post[:user] = 1
```
Although, the latter is more efficient than the former.