-- Mission Control Tower Recipe Prototype
-- Recipe: 5 radars + 100 processing units (as per spec)

data:extend({
  {
    type = "recipe",
    name = "mission-control-tower",
    enabled = false,  -- Unlocked by technology
    energy_required = 10,  -- 10 seconds to craft
    ingredients = {
      {type = "item", name = "radar", amount = 5},
      {type = "item", name = "processing-unit", amount = 100}
    },
    results = {
      {type = "item", name = "mission-control-tower", amount = 1}
    }
  }
})
