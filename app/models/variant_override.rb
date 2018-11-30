class VariantOverride < ActiveRecord::Base
  extend Spree::LocalizedNumber

  acts_as_taggable

  belongs_to :hub, class_name: 'Enterprise'
  belongs_to :variant, class_name: 'Spree::Variant'

  validates_presence_of :hub_id, :variant_id
  # Default stock can be nil, indicating stock should not be reset or zero, meaning reset to zero. Need to ensure this can be set by the user.
  validates :default_stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  after_save :refresh_products_cache_from_save
  after_destroy :refresh_products_cache_from_destroy

  default_scope where(permission_revoked_at: nil)

  scope :for_hubs, lambda { |hubs|
    where(hub_id: hubs)
  }

  scope :distinct_import_dates, lambda {
    select('DISTINCT variant_overrides.import_date').
      where('variant_overrides.import_date IS NOT NULL').
      order('import_date DESC')
  }

  localize_number :price

  def self.indexed(hub)
    Hash[
      for_hubs(hub).preload(:variant).map { |vo| [vo.variant, vo] }
    ]
  end

  def stock_overridden?
    count_on_hand.present?
  end

  def move_stock!(quantity)
    unless stock_overridden?
      Bugsnag.notify RuntimeError.new "Attempting to move stock of a VariantOverride without a count_on_hand specified."
      return
    end

    if quantity > 0
      increment! :count_on_hand, quantity
    elsif quantity < 0
      decrement! :count_on_hand, -quantity
    end
  end

  def default_stock?
    default_stock.present?
  end

  def reset_stock!
    if resettable
      if default_stock?
        self.attributes = { count_on_hand: default_stock }
        self.save
      else
        Bugsnag.notify RuntimeError.new "Attempting to reset stock level for a variant with no default stock level."
      end
    end
    self
  end

  private

  def refresh_products_cache_from_save
    OpenFoodNetwork::ProductsCache.variant_override_changed self
  end

  def refresh_products_cache_from_destroy
    OpenFoodNetwork::ProductsCache.variant_override_destroyed self
  end
end
