module MingleEvents
  module Processors
    
    # Provides ability to lookup card data, e.g., card's type name, for any
    # card serving as a source for the stream of events. Implements two interfaces:
    # the standard event processing interface, handle_events, and also, for_card_event,
    # which returns of has of card data for the given event. See the project README
    # for additional information on using this class in a processing pipeline.
    class CardData
            
      def initialize(mingle_access, project_identifier, custom_properties = ProjectCustomProperties.new(mingle_access, project_identifier))
        @mingle_access = mingle_access
        @project_identifier = project_identifier
        @custom_properties = custom_properties
        @card_data_by_number_and_version = nil
      end
      
      # Capture which events are card events and might require data lookup. The
      # actual data retrieval is lazy and will only occur as needed.
      def process_events(events)
        @card_events = events.select(&:card?)     
        events      
      end
      
      # Return a hash of data for the card that sourced the passed event. The data
      # will be for the version of the card that was created by the event and not the 
      # current state of the card. Currently supported data keys are: :number, :version,
      # :card_type_name
      def for_card_event(card_event)
        if @card_data_by_number_and_version.nil?
          load_bulk_card_data
        end
        key = data_key(card_event.card_number, card_event.version)
        @card_data_by_number_and_version[key] ||= load_card_data_for_event(card_event)
      end
      
      private
      
      def data_key(number, version)
        "#{number}:#{version}"
      end
      
      def load_bulk_card_data
        @card_data_by_number_and_version = {}
        
        # TODO: figure out max number of card numbers before we have to chunk this up.  or does mingle
        # figure out how to handle a too-large IN clause?
        card_numbers = @card_events.map(&:card_number).uniq
        path = "/api/v2/projects/#{@project_identifier}/cards/execute_mql.xml?mql=WHERE number IN (#{card_numbers.join(',')})"
        
        raw_xml = @mingle_access.fetch_page(URI.escape(path))
        doc = Nokogiri::XML(raw_xml)
        
        doc.search('/results/result').map do |card_result|
          card_number = card_result.at('number').inner_text.to_i
          card_version = card_result.at('version').inner_text.to_i
          custom_properties = {}
          @card_data_by_number_and_version[data_key(card_number, card_version)] = {
            :number => card_number,
            :version => card_version,
            :card_type_name => card_result.at('card_type_name').inner_text,
            :custom_properties => custom_properties
          }
          card_result.children.each do |child|
            if child.name.index("cp_") == 0
              value = if child['nil'] == "true"
                nil
              else
                child.inner_text
              end
              custom_properties[@custom_properties.property_name_for_column(child.name)] = value
            end
          end
        end
      end
    
      def load_card_data_for_event(card_event)
        begin
          page_xml = @mingle_access.fetch_page(card_event.card_version_resource_uri)
          doc = Nokogiri::XML(page_xml)
          custom_properties = {}
          result = {
            :number => card_event.card_number,
            :version => card_event.version,
            :card_type_name => doc.at('/card/card_type/name').inner_text,
            :custom_properties => custom_properties
          }
          doc.search('/card/properties/property').each do |property|
            custom_properties[property.at('name').inner_text] = property.at('value').inner_text
          end
          
          result
        rescue HttpError => httpError
          raise httpError unless httpError.not_found?

        end
      end
      
    end
    
  end
end