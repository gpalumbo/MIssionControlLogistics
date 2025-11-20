-- Receiver Combinator Recipe Prototype
-- Recipe: 10 red circuits + 5 radars + 1 arithmetic combinator (as per spec)

data:extend({
  {
    type = "recipe",
    name = "receiver-combinator",
    enabled = false,  -- Unlocked by technology
    energy_required = 5,  -- 5 seconds to craft (faster than MC tower since smaller)
    ingredients = {
      {type = "item", name = "advanced-circuit", amount = 10},  -- Red circuits
      {type = "item", name = "radar", amount = 5},
      {type = "item", name = "arithmetic-combinator", amount = 1}
    },
    results = {
      {type = "item", name = "receiver-combinator", amount = 1}
    }
  }
})
