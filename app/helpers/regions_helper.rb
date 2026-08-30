module RegionsHelper
  def render_regions_tree(regions, indent_level = 1)
    return "" if regions.blank?

    regions.each do |region|
      r_name = region[:name] || region['name']
      r_state = region[:is_state] || region['is_state']
      r_appellation = region[:is_appellation] || region['is_appellation']
      r_id = region[:id] || region['id']
      r_children = region[:children] || region['children'] || []
      type_labels = []
      type_labels << "State" if r_state
      type_labels << "Appellation" if r_appellation
      type_info = type_labels.any? ? " (#{type_labels.join(' / ')})" : ''

      if r_children.any?
        concat(
          content_tag(:div, class: 'region-tree-node') do
            content_tag(:details, class: 'region-tree-node__details') do
              concat(
                content_tag(:summary, class: 'region-tree-node__summary') do
                  concat(content_tag(:span, '+', class: 'region-tree__toggle'))
                  concat(link_to("#{r_name}#{type_info}", region_path(r_id), class: 'region-tree-node__name'))
                end
              )
              concat(
                content_tag(:div, class: 'region-tree-node__children') do
                  render_regions_tree(r_children, indent_level + 1).html_safe
                end
              )
            end
          end
        )
      else
        concat(
          content_tag(:div, class: 'region-tree-node') do
            content_tag(:div, class: 'region-tree-node__content', style: "padding-left: #{indent_level * 1.5}rem;") do
              concat(content_tag(:span, ' ', class: 'region-tree__toggle'))
              concat(link_to("#{r_name}#{type_info}", region_path(r_id), class: 'region-tree-node__name'))
            end
          end
        )
      end
    end
    ""
  end
end
