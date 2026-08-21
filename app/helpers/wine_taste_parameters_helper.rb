module WineTasteParametersHelper
  def wine_taste_parameter_score_class(wine_taste_parameter)
    "wine-taste-parameter--score-#{wine_taste_parameter.score.to_i.clamp(0, 100)}"
  end

  def wine_taste_parameter_label(wine_taste_parameter)
    wine_taste_parameter.taste_parameter&.label || "Unknown parameter"
  end
end