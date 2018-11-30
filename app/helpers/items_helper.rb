# frozen_string_literal: true

module ItemsHelper
  def item_category(item)
    case item.category
    when Item::CATEGORY_COLD
      content_tag(:span, '冷', class: 'badge badge-info')
    when Item::CATEGORY_FROZEN
      content_tag(:span, '凍', class: 'badge badge-primary')
    end
  end
end