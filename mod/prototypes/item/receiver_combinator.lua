-- Receiver Combinator Item Prototype

data:extend({
  {
    type = "item",
    name = "receiver-combinator",
    icon = "__mission-control__/graphics/entities/receiver_icon.png",
    icon_size = 64,
    subgroup = "circuit-network",  -- Same as other combinators
    order = "c[combinators]-z[receiver-combinator]",  -- After other combinators in build menu
    place_result = "receiver-combinator",
    stack_size = 25  -- As per spec (standard for combinators is 50, but spec says 25)
  }
})
