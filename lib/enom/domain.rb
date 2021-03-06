module Enom

  class Domain
    include HTTParty
    include ContactInfo

    # The domain name on Enom
    attr_reader :name

    # Second-level and first-level domain on Enom
    attr_reader :sld, :tld

    # Domain expiration date (currently returns a string - 11/9/2010 11:57:39 AM)
    attr_reader :expiration_date


    def initialize(attributes)
      @name = attributes["DomainName"] || attributes["domainname"]
      @sld, @tld = @name.split('.')

      expiration_date_string = attributes["expiration_date"] || attributes["status"]["expiration"]
      @expiration_date = Date.strptime(expiration_date_string.split(' ').first, "%m/%d/%Y")

      # If we have more attributes for the domain from running GetDomainInfo
      # (as opposed to GetAllDomains), we should save it to the instance to
      # save on future API calls
      if attributes["services"] && attributes["status"]
        set_extended_domain_attributes(attributes)
      end
    end

    # Find the domain (must be in your account) on Enom
    def self.find(name)
      sld, tld = name.split('.')
      response = Client.request('Command' => 'GetDomainInfo', 'SLD' => sld, 'TLD' => tld)["interface_response"]["GetDomainInfo"]
      Domain.new(response)
    end


    # Determine if the domain is available for purchase
    def self.check(name)
      if available?(name)
        "available"
      else
        "unavailable"
      end
    end


    # Determine if a list of domains are available for purchase
    # Returns an array of available domain names
    # NOTE: there is a bug with arrays... Use only defaults until enom fixes XML result
    def self.check_many(sld, tldvalue)
      tldlist = nil
      tld = nil
      result = []

      if tldvalue.kind_of?(Array)
         tldlist = tldvalue.join(",")       # array of TLDs to check (ex: ['us','ca','com'] )
      else
         tld = tldvalue                     # default lists 
                                            # *   returns: com, net, org, info, biz, us, ws, cc, tv, bz, nu 
                                            # *1  returns: com, net, org, info, biz, us, ws 
                                            # *2  returns: com, net, org, info, biz, us 
                                            # @   returns: com, net, org 
      end


      response = Client.request("Command" => "Check", "SLD" => sld, "TLD" => tld, "TLDList" => tldlist)

      response["interface_response"].each do | k, v|
        
        if v == "210" #&& k[0,6] == "RRPCode"
          pos = k[7..k.size]
         result << response["interface_response"]["Domain#{pos}"] unless k.blank?
        end
      end

      return result
    end


    # Boolean helper method to determine if the domain is available for purchase
    def self.available?(name)
      sld, tld = name.split('.')
      response = Client.request("Command" => "Check", "SLD" => sld, "TLD" => tld)["interface_response"]["RRPCode"]

      if response == "210"
        true
      else
        false
      end
    end

    # Find and return all domains in the account
    def self.all(options = {})
      response = Client.request("Command" => "GetAllDomains")["interface_response"]["GetAllDomains"]["DomainDetail"]

      domains = []
      response.each {|d| domains << Domain.new(d) }
      return domains
    end

    # Purchase the domain
    def self.register!(name, options = {})
      sld, tld = name.split('.')
      opts = {}
      if options[:nameservers]
        count = 1
        options[:nameservers].each do |nameserver|
          opts.merge!("NS#{count}" => nameserver)
          count += 1
        end
      else
        opts.merge!("UseDNS" => "default")
      end
      opts.merge!('NumYears' => options[:years]) if options[:years]
      response = Client.request({'Command' => 'Purchase', 'SLD' => sld, 'TLD' => tld}.merge(opts))
      Domain.find(name)
    end


    # Create an order to transfer domains from another registrar to eNom or one of its resellers
    def self.transfer!(name, auth, options = {})  
      sld, tld = name.split('.')
      
      #Default options
      opts = {
      	"OrderType" => "AutoVerification",
      	"DomainCount" => 1, #The number of domain names to be submitted on the order.
        "SLD1" => sld,
      	"TLD1" => tld,
      	"AuthInfo1" => auth, #authorization key from the user
      	"UseContacts" => 1   #Set UseContacts=1 to transfer existing Whois contacts with a domain that does not require extended attributes.
      }

    	if options[:renew]
    	  opts.merge!("Renew" => 1)
    	end

      response = Client.request({'Command' => 'TP_CreateOrder'}.merge(opts))["ErrCount"]

      if response.to_i > 0
         return false 
      else
         return true
      end

    end


    # Renew the domain
    def self.renew!(name, options = {})
      sld, tld = name.split('.')
      opts = {}
      opts.merge!('NumYears' => options[:years]) if options[:years]
      response = Client.request({'Command' => 'Extend', 'SLD' => sld, 'TLD' => tld}.merge(opts))
      Domain.find(name)
    end

    # Lock the domain at the registrar so it can't be transferred
    def lock
      Client.request('Command' => 'SetRegLock', 'SLD' => sld, 'TLD' => tld, 'UnlockRegistrar' => '0')
      @locked = true
      return self
    end

    # Unlock the domain at the registrar to permit transfers
    def unlock
      Client.request('Command' => 'SetRegLock', 'SLD' => sld, 'TLD' => tld, 'UnlockRegistrar' => '1')
      @locked = false
      return self
    end

    # Check if the domain is currently locked.  locked? helper method also available
    def locked
      unless defined?(@locked)
        response = Client.request('Command' => 'GetRegLock', 'SLD' => sld, 'TLD' => tld)['interface_response']['reg_lock']
        @locked = response == '1'
      end
      return @locked
    end
    alias_method :locked?, :locked

    # Check if the domain is currently unlocked.  unlocked? helper method also available
    def unlocked
      !locked?
    end
    alias_method :unlocked?, :unlocked

    # Return the DNS nameservers that are currently used for the domain
    def nameservers
      get_extended_domain_attributes unless @nameservers
      return @nameservers
    end

    def update_nameservers(nameservers = [])
      count = 1
      ns = {}
      if (2..12).include?(nameservers.size)
        nameservers.each do |nameserver|
          ns.merge!("NS#{count}" => nameserver)
          count += 1
        end
        Client.request({'Command' => 'ModifyNS', 'SLD' => sld, 'TLD' => tld}.merge(ns))
        @nameservers = ns.values
        return self
      else
        raise InvalidNameServerCount
      end
    end

    def expiration_date
      unless defined?(@expiration_date)
        date_string = @domain_payload['interface_response']['GetDomainInfo']['status']['expiration']
        @expiration_date = Date.strptime(date_string.split(' ').first, "%m/%d/%Y")
      end
      @expiration_date
    end

    def registration_status
      get_extended_domain_attributes unless @registration_status
      return @registration_status
    end

    def active?
      registration_status == "Registered"
    end

    def expired?
      registration_status == "Expired"
    end

    def renew!(options = {})
      Domain.renew!(name, options)
    end

    private

    # Make another API call to get all domain info. Often necessary when domains are
    # found using Domain.all instead of Domain.find.
    def get_extended_domain_attributes
      sld, tld = name.split('.')
      attributes = Client.request('Command' => 'GetDomainInfo', 'SLD' => sld, 'TLD' => tld)["interface_response"]["GetDomainInfo"]
      set_extended_domain_attributes(attributes)
    end

    # Set any more attributes that we have to work with to instance variables
    def set_extended_domain_attributes(attributes)
      @nameservers = attributes['services']['entry'].first['configuration']['dns']
      @registration_status = attributes['status']['registrationstatus']
      return self
    end

  end
end
