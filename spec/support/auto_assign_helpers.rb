# frozen_string_literal: true

# Shared setup for the auto-assign specs (profiles, taste parameters, grapes).
module AutoAssignHelpers
  def self.make_taste_parameter(slug, label)
    TasteParameter.find_by(slug: slug) || TasteParameter.create!(
      slug: slug,
      label: label,
      label_1: "Low",
      label_2: "Medium (-)",
      label_3: "Medium",
      label_4: "Medium (+)",
      label_5: "High",
      help: "A taste parameter used by the auto-assign specs."
    )
  end

  def self.make_profile(name, grapes = [name], color = "Red")
    profile = WineProfile.create!(name: name, color: color, notes: "[]", serving: "x")
    grapes.each do |grape_name|
      grape = Grape.find_by_name_or_synonym(grape_name)
      profile.profile_grapes << (grape || Grape.create!(name: grape_name, color: "red"))
    end
    profile
  end
end
