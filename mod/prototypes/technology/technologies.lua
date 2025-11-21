-- Mission Control Technology Prototype

data:extend({
  {
    type = "technology",
    name = "mission-control",
    icon = "__mission-control__/graphics/icons/tower_icon.png",
    icon_size = 120,
    effects = {
      {
        type = "unlock-recipe",
        recipe = "mission-control-tower"
      },
      {
        type = "unlock-recipe",
        recipe = "receiver-combinator"
      }
    },
    prerequisites = {
      "radar",                    -- Radar technology
      "space-platform-thruster",  -- Space platform technology (2.0 name)
      "space-science-pack",       -- Space science
      "logistic-system"           -- Logistic system (for logistics integration)
    },
    unit = {
      count = 1000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60  -- 60 seconds per research unit
    },
    order = "g-a-z"  -- Place after other related technologies
  }
})
