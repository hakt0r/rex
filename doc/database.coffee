# define models
Post = db.define "Post",
  title:
    type: String
    length: 255
  content:
    type: Schema.Text
  date:
    type: Date
    default: Date.now
  published:
    type: Boolean
    default: false
    index: true

# simplier way to describe model
User = db.define "User",
  name: String
  bio: Schema.Text
  approved: Boolean
  joinedAt: Date
  age: Number

# define any custom method
User::getNameAndAge = ->
  @name + ", " + @age

# setup relationships
User.hasMany Post,
  as: "posts"
  foreignKey: "userId"
# creates instance methods:
# user.posts(conds)
# user.posts.build(data) // like new Post({userId: user.id});
# user.posts.create(data) // build and save

Post.belongsTo User,
  as: "author"
  foreignKey: "userId"
# creates instance methods:
# post.author(callback) -- getter when called with function
# post.author() -- sync getter when called without params
# post.author(user) -- setter when called with object

# work with models:
user = new User
user.save (err) ->
  post = user.posts.build(title: "Hello world")
  post.save console.log


# or just call it as function (with the same result):
user = User()

# user.save(...);

# Common API methods

# just instantiate model
new Post

# save model (of course async)
Post.create cb

# all posts
Post.all cb

# all posts by user
Post.all
  where:
    userId: user.id

  order: "id"
  limit: 10
  skip: 20


# the same as prev
user.posts cb

# get one latest post
Post.findOne
  where:
    published: true

  order: "date DESC"
, cb

# same as new Post({userId: user.id});
user.posts.build

# save as Post.create({userId: user.id}, cb);
user.posts.create cb

# find instance by id
User.find 1, cb

# count instances
#User.count([conditions, ]cb)
# destroy instance
user.destroy cb

# destroy all instances
User.destroyAll cb

# Setup validations
User.validatesPresenceOf "name", "email"
User.validatesLengthOf "password",
  min: 5
  message:
    min: "Password is too short"

User.validatesInclusionOf "gender",
  in: ["male", "female"]

User.validatesExclusionOf "domain",
  in: ["www", "billing", "admin"]

User.validatesNumericalityOf "age",
  int: true

User.validatesUniquenessOf "email",
  message: "email is not unique"

user.isValid (valid) ->
  user.errors  unless valid # hash of errors {attr: [errmessage, errmessage, ...], attr: ...}
