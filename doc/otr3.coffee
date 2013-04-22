###
 OTR3-em - Off-the-Record Messaging [native bindings]
###

# Getting started
# Require the otr3 module (underlying gcrypt and otr libraries will be initialised. 
otr = require("otr3")

# Returns version information of the native libotr on your systtem:
console.log "Using version:", otr.version()

# The User object is used to manage a user's accounts (public keys) and known fingerprints.
# otr.User( config )
otr = require("otr3")
user = new otr.User(
  keys: "/alice.keys" #path to OTR keys file (required)
  fingerprints: "alice.fp" #path to fingerprints file (required)
)

# All data is loaded in memory (UserState) and persisted on the file system.
# If specified files exist the keys and fingerprints will be loaded automatically.
# A warning will be logged to the console otherwise.
user.accounts()

# We can check what accounts have been load..
user.accounts().forEach (account) ->
  console.log account.fingerprint
###
  [ { accountname: 'alice@jabber.org',
      protocol: 'xmpp',
      fingerprint: '65D366AF CF9B065F 41708CB0 1DC26F61 D3DF5935' } ]
###

# user.generateKey(accountname,protocol,function(err) )
# To generate an OTR key for a given accountname and protocol:
# (If a key already exists it will be overwritten)
user.generateKey "alice@jabber.org", "xmpp", (err) ->
  if err
    console.log "something went wrong!", err.message
  else
    console.log "Generated Key Successfully"


# user.fingerprint(accountname,protocol)
# To retreive the fingerprint of a key:
user.fingerprint "alice@jabber.org", "xmpp"
# returns
#   '65D366AF CF9B065F 41708CB0 1DC26F61 D3DF5935'

# Create a ConnContext(). accountname and protocol will select the key to use in this context, and buddy_name 
# is our chosen name for the remote party which is stored in the fingerprints file.
user.ConnContext(accountname, protocol, buddy_name)

user.writeFingerprints() # Writes fingerprints out to file.

# otr.ConnContext()
#
#A ConnContext with buddy 'BOB' is created from a User() object. The last argument is
#our selected name for buddy Bob.
#
context = alice.ConnContext("alice@jabber.org", "xmpp", "BOB")
# The following properties of the ConnContext object are exposed (Read-Only):
poperties =
  protocol: string  # eg. "xmpp"
  username: string  # name we have given to the recipient, "BOB"
  accountname: string  # account name of the otr key, eg. "alice@jabber.org"
  fingerprint: string  # active fingerprint - of recipient's key
  protocol_version: number  # otr protocol version in use, eg. 2
  msgstate: number  # 0 = plaintext, 1 = encrypted
  smstate: number  # current state of the SMP (Socialist Millionaire's Protocol)
  trust: string  # 'smp' if recipient's fingerprint has been verified by SMP.

###
  otr.Session()
  To setup an OTR conversation with a buddy, create a Session(). As arguments
  it takes a User, ConnContext, and a set of parameters for the session. Session instances
  are event emitters.
###

#Setting up a Session()
session = new otr.Session(alice, BOB,
  policy: otr.POLICY("ALWAYS") #optional policy - default = otr.POLICY("DEFAULT")
  MTU: 5000 #optional - max fragment size in bytes - default=0,no-fragmentation
  secret: "SECRET" #secret for SMP authentication.
  secrets:
    "question-1": "secret-1"
    "question-2": "secret-2" #questions,answers pairs for SMP Authentication.
)

# Starting and Ending an OTR conversation
# session.connect()
# This can be used if we wish to initiate the protocol without sending an actual message.
session.connect() # will initiate the otr protocol
session.close()   # will end the otr session.

# Exchanging Messages
session.send(message) # will fragment and send message.toString()
session.recv(message) # when receiving message

# Authenticating with SMP (Socialist Millionaire's Protocol)//
session.start_smp([secret]) # starts SMP authentication. If otional [secret] is not passed it is taken from the parameters.
session.start_smp_question(question,[secret]) # start SMP authentication with a question and optional [secret]. If secret is not passed it is taken from the parameters.
session.respond_smp([secret]) # responds to SMP authentication request with optional [secret]. If secret is not passed it is taken from the parameters.

# At anytime we can check encryption and trust level of the session
session.isEncrypted() # returns true only if current session is encrypted.
session.isAuthenticated() # return true only if the fingerprint of the buddy has been authenticated/verified by SMP.

# Handling Session events
session.on "message", (msg,encrypted)->                     # encrypted - received //msg// message. //encrypted// will be true if it was received encrypted.
session.on "inject_message", (msg_fragment)->               # - encrypted msg_fragment to be sent to buddy.
session.on "gone_secure", ->                                # message exchange is now encrypted.
session.on "gone_insecure", ->                              # message exchange is now in plain text.
session.on "still_secure", ->                               # encryption re-negotiated. message exchange is encrypted.
session.on "create_privkey", (accountname,protocol) ->      # a private key for account/protocol specified was not found and needs to be created.
session.on "new_fingerprint", (fingerprint)->               # first time we are seeing buddy's fingerprint. This is a que to begin authentication.
session.on "smp_request", (question)->                      # buddy has started SMP authentication. (possibly with a question)
session.on "smp_complete", ->                               # SMP authentication completed successfully.
session.on "smp_failed", ->                                 # SMP failed (usually buddy doesn't know the secret)
session.on "smp_aborted", ->                                # SMP (something went wrong at the protocol level)
session.on "remote_disconnected", ->                        # session closed() [remotely]
session.on "update_context_list", ->                        # fired when underlying ConnContext changes (inteded mostly for UI updates)
session.on "shutdown", ->                                   # session was closed() [locally]
session.on "display_otr_message", (msg)->                   # human readable notification message
session.on "notify", (title, primary,secondary)->           # notification (fired after display_otr_message for same notification message)
session.on "log_message", (msg)                             # debug log messages from libotr

# The policy is used as a parameter when setting up a Session().
otr = require("otr3")
policy = otr.POLICY("DEFAULT")
# available policies
"NEVER"
"ALLOW_V1"
"ALLOW_V2"
"REQUIRE_ENCRYPTION"
"SEND_WHITESPACE_TAG"
"WHITESPACE_START_AKE"
"ERROR_START_AKE"
"VERSION_MASK"
"OPPORTUNISTIC"
"MANUAL"
"ALWAYS"
"DEFAULT"