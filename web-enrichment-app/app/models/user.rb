class User < ApplicationRecord
  include DomainEventPublishable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, # :registerable,
         :recoverable, :rememberable, :validatable

  def domain_event_payload
    attributes.except("id", "encrypted_password", "reset_password_token").transform_values { |v| v.is_a?(Time) ? v.iso8601 : v }
  end
end
