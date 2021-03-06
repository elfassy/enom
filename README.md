Enom
====

A ruby wrapper for the Enom Domain Registrar's API for checking domain name availability, domain contact information, name server settings, etc. Enom provides an API for all of their services, unfortunately it's got hundreds of commands and it's pretty tough to test.  This library aims to make calls to their API trivial and also makes it simple to continually add API commands without much effort.

# Installation

    gem install enom

# Account Operations

```ruby
# Set some initial values to allow connections to your account
Enom::Client.username = "foo"
Enom::Client.password = "bar"
Enom::Client.test = true
# Declaring test mode is optional, defaults to false (production)
# Test mode will run commands on Enom's reseller test platform
```

Once these are set, subsequent commands will make calls to the API using your credentials (HTTPS).  Any methods in the library that charge or refund the account in any way end with a bang (!).

```ruby
# Get account balance
Enom::Account.balance
# => 12.34

# Find a domain in your account
d = Enom::Domain.find("example.com")
# => #<Enom::Domain:0x1019f3b78...

# Check availability (boolean)
Enom::Domain.available?("example.com")
# => true

# Another way to check domain availability
Enom::Domain.check("example.com")
# => 'available'
Enom::Domain.check("google.com")
# => 'unavailable'

# Find all available domains
Enom::Domain.check_many("example","*")
# => ["example.com","example.us"]

# Register a domain
d = Enom::Domain.register!("example.com")
# => #<Enom::Domain:0x1019f3b78...

# Transfer a domain
d = Enom::Domain.transfer!("example.com", "authorizationcode")
# => true
```

# Domain Operations

```ruby
# Return the domain name
d.name
# => 'example.com'

# Check if domain is locked
d.locked?
# => true

# Check if domain is unlocked
d.unlocked?
# => false

# Unlock the domain for transfer
d.unlock

# Lock the domain to the registrar
d.lock

# Get name servers
d.nameservers
# => ['ns1.example.com', 'ns2.example.com', 'ns3.example.com']

# Update name servers
d.update_nameservers(['ns1.example.com', 'ns2.example.com', 'ns3.example.com'])

# Get expiration date
d.expiration_date
# => Returns a Date object

# Check if domain is expired
d.expired?
# => true

# Get registration status
d.registration_status
# => 'Registered' or 'Expired'

# Renew domain (defaults to 1 year)
d.renew!

# Renew domain for specific number of years
d.renew!(:years => 3)
```
[![Build Status](https://secure.travis-ci.org/bensie/enom.png)](http://travis-ci.org/bensie/enom)

Copyright
---------

Copyright (c) 2011 James Miller
