# frozen_string_literal: true

module Admin
  module EventsHelper
    def event_type_class(event_type)
      case event_type
      when /\.created$/ then "event-type-created"
      when /\.updated$/ then "event-type-updated"
      when /\.destroyed$/ then "event-type-destroyed"
      when /\.approved$/ then "event-type-approved"
      when /\.processed$/ then "event-type-processed"
      else "event-type-default"
      end
    end
  end
end
