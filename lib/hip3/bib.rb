#!/usr/bin/ruby

require 'marc'
require 'stringio'

module Hip3
	# Bib record/object from HIP. Fetches in it's own data via
	# HIP XML interface. Which may make it sensitive, sorry. If not fetched in yet, # for an item with 'copy' (serial) control, we  
	# have to do TWO fetches to get complete information, one for summary
	# holdings statements, plus another for items. Sigh, sorry. 
	class Bib 
		attr_accessor :httpSession, :hip_base_url
		# should have copies or items, not both
		attr_accessor :bibNum, :copies, :items 
		# CustomFieldLookup objects
		attr_accessor :item_field_lookup, :copy_field_lookup, :bib_field_lookup # We cache HIP's XML representation of bib with and without items serial items. 
		attr_accessor :bib_xml, :xml_with_items 
		# and the beautiful MARC xml object for the bib, ruby-marc object. 
		attr_accessor :marx_xml
		
    # First arg: Horizon BibNo this thing represents.
    # Second arg: Net::URI representing HIP base path.
    # labelled args:
		# bib_xml_doc => is optional rexml representing bib from HIP. If you have
    # it already, give it to us and we won't have to fetch it. 
    # http_session => optional already initialized http session. You are
    #                 advised to use a Hip3::HTTPSession for it's error 
    #                 handling.
		def initialize(argBibNum, a_hip_base_path, params)

      self.bibNum = argBibNum
      raise ArgumentException.new("Nil 1st argument: You must supply a bib number to first arg of Bib.new") unless self.bibNum
      
      self.hip_base_url = a_hip_base_path
      raise ArgumentException.new("Nil 2nd arg: You must supply the HIP instance base URL as a Net::URI object in 2nd arg to Bib.new") unless self.hip_base_url
			
			self.httpSession = params[:http_session]
      self.httpSession ||= Hip3::HTTPSession.create(hip_base_url.host() )
      
			self.copies = nil

			@bib_xml = params[:bib_xml_doc]
		end

		
		
		def hip_http_path
			# 1000 items and copies per page, we want em all
			return hip_base_url.path + "?index=BIB&term=#{bibNum}&ipp=1000&cpp=1000" 
		end
		def hip_http_xml_path
			return hip_http_path + "&GetXML=1"
		end
	
		# Fetch in our data from HIP. Called lazily by accessor methods. 
		def load_from_store
				
			# If we have serial copies, load those. We never should have both, but oh well. 
			serialElements = bib_xml.elements.to_a('searchresponse/subscriptionsummary/serial')
			self.copies = serialElements.collect do |serialElement|
				holding = Hip3::SerialCopy.new( self, serialElement )				
			
				holding # collect holdings
			end
			@copies_loaded = true
						
			# If we didn't have copies, we might have items directly in this bib.  
			if (self.copies.length == 0 &&
				!bib_xml.elements.to_a('searchresponse/items/searchresults/results/row').nil?)
				self.xml_with_items = bib_xml
				load_items_from_store
			end
			@items_loaded = true

		end
	
		# This method gets the XML from HIP and puts it in an ivar. 
		def xml_with_items
			# first try to load our bib record, that might give us items.
			unless (@xml_with_items)
				load_from_store
			end
			# If we still don't have it, have to load the item xml
			unless (@xml_with_items)
				# Got to make another request
				# give us up to 1000 item records!
				bibWithItemsRequestPath = self.hip_http_xml_path + "&view=items&ipp=1000"
        
        
				resp = Hip3::HTTPSession.safe_get(httpSession, bibWithItemsRequestPath)
				@xml_with_items = REXML::Document.new( resp.body )
			end
		
			return @xml_with_items
		end
		
		def bib_xml
			unless (@bib_xml)
				summaryRequestPath = hip_http_xml_path
		
				resp = Hip3::HTTPSession.safe_get(httpSession, summaryRequestPath )
				@bib_xml = REXML::Document.new( resp.body )						
			end
			
			return @bib_xml
		end

		def marc_xml			
			# Sadly, loading this takes ANOTHER request. At least this
			# request, unlike the HIP requests, is speedy. We need this
      # for getting 856 urls with sub-fields. Depends on Casey
      # Durfee's package to provide marcxml from hip being installed. 
			unless (@marc_xml)
				# should have copies or items, not both
				path = "/mods/?format=marcxml&bib=#{bibNum}"
        #host = hip_base_url.host
        host = 'catalog.library.jhu.edu'
        
        # put in a rescue on bad http, reword error. 
          resp = Hip3::HTTPSession.start(host, hip_base_url.port) {|http| http.get(path) }
        
        
				
				reader = MARC::XMLReader.new( StringIO.new(resp.body.to_s) )
				# there should only be one record in there, just grap one.
				
				@marc_xml = reader.find { true }
			end
			return @marc_xml
		end
			
		# Load _serial_ Item data from HIP belonging to this BIB. Called lazily by accessors.
		# Will also work for mono item data, but no reason to call it, can get mono item data
		# without this extra fetch. 
		def load_items_from_store
					
			itemRowElements =  xml_with_items.elements.to_a('searchresponse/items/searchresults/results/row');			
			itemRowElements.each do | el |
				# constructor will take care of registering the thing with us
				Hip3::Item.new(el, self)
			end
			# Tell all our copies they're loaded, so they won't try and load again
			copies.each { |c| c.items_loaded = true }
			
		end
	
		def item_field_lookup
			
			# This guy loads our lookup obj
			unless @item_field_lookup
				xml = self.xml_with_items
				itemLabels = xml.elements.to_a('searchresponse/items/searchresults/header/col/label').collect {|e| e.text}				
				@item_field_lookup = CustomFieldLookup.new(itemLabels)
			end
			
			return @item_field_lookup
		end
		
		# Lookup custom HIP admin assigned fields in copy summary record
		# => CustomFieldLookup object. 
		def copy_field_lookup
			unless @copy_field_lookup
				labels = self.bib_xml.elements.to_a('searchresponse/subscriptionsummary/header/col/label').collect {|e| e.text}
				@copy_field_lookup = CustomFieldLookup.new(labels)
			end
			
			return @copy_field_lookup
		end

		def bib_field_lookup
			unless ( @bib_field_lookup)
				labels = self.bib_xml.elements.to_a('searchresponse/fullnonmarc/header/col/label').collect {|e| e.text}
				@bib_field_lookup = CustomFieldLookup.new(labels)
			end
			return @bib_field_lookup
		end

		# Look up a field added in HIP Admin screen, by label given in that screen.
		def custom_field_for_label(label)
			dataRows = self.bib_xml.elements.to_a('searchresponse/fullnonmarc/results/row[1]/cell');
			return bib_field_lookup.text_value_for(dataRows, label)
		end

		# copy records, in case of serial bib
		def copies
			self.load_from_store unless @copies_loaded
			return @copies || [] # never return nil, always return an array
		end
		
		# Items directly held by this bib, only in case of mono bib
		def items
			self.load_from_store unless @items_loaded
			
			return @items || []
		end
		
		# Returns items OR copies, depending on whether it's a serial
		# or a mono bib. HIP doesn't generally allow a mixture of of both.
		def holdings
			return items + copies
		end
		
		# We could try to store the copies in a hash for efficiency, but
		# we're only going to have a handful, it's not worth it. 
		def copy_for_id(copy_id)
			copies.find { |c|  c.id == copy_id }
		end
				
		
		# Will add this to an appropriate Copy record if one exists,
		# otherwise directly to our items array. According to HIP's
		# constriants, a bib should never have copies _and_ directly
		# included items, just one or the other. 
		def register_item(item)			
			copy = copy_for_id( item.copy_id )
			if ( copy.nil? )
				# can't find a copy record, guess it's a directly registered item
				register_direct_item( item )
			else
				copy.register_item( item )
			end
			
		end
		
		# An item that does not have a copy parent, but is directly
		# related to the big. 
		def register_direct_item( item )
			@items ||= []
			@items.push( item ) if ! @items.include?(item)	
		end

		def http_url
        
		
			return "#{hip_base_url.scheme}://#{hip_base_url.host}:#{hip_base_url.port}#{hip_http_path}"
		end
		
		def to_s
			return "#<Hip3::Bib bibnum=#{bibNum} #{http_url}>"
		end
	end
	
					
end