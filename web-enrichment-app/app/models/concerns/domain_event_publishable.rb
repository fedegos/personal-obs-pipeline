# frozen_string_literal: true

# Publica a Kafka (topic domain_events) todo cambio persistente create/update/destroy
# para tener una historia reconstruible. Incluir en modelos que deban auditarse.
module DomainEventPublishable
  extend ActiveSupport::Concern

  included do
    after_commit :publish_domain_event, on: [ :create, :update, :destroy ]
  end

  def publish_domain_event
    action = domain_event_action
    return if action.blank?

    event_type = "#{domain_event_entity_type.underscore}.#{action}"
    entity_id  = domain_event_entity_id
    payload    = domain_event_payload

    message = {
      event_type:  event_type,
      entity_type: domain_event_entity_type,
      entity_id:   entity_id.to_s,
      action:      action,
      payload:     payload,
      timestamp:   Time.current.iso8601
    }
    message[:metadata] = domain_event_metadata if respond_to?(:domain_event_metadata, true)

    key = "#{domain_event_entity_type}:#{entity_id}"

    Karafka.producer.produce_async(
      topic:   "domain_events",
      payload: message.to_json,
      key:     key
    )
  rescue => e
    Rails.logger.error "❌ Error publicando domain event (#{event_type}): #{e.message}"
  end

  # Sobrescribir en modelos para excluir atributos sensibles (ej. User: encrypted_password)
  def domain_event_payload
    attributes.except("id").transform_values { |v| v.is_a?(Time) ? v.iso8601 : v }
  end

  def domain_event_entity_type
    self.class.name
  end

  def domain_event_entity_id
    respond_to?(:event_id) ? event_id : id
  end

  def domain_event_action
    return "created"  if saved_change_to_id?
    return "destroyed" if destroyed?
    "updated"
  end
end
