-- Mission Control Tower Item Prototype

data:extend({
  {
    type = "item",
    name = "mission-control-tower",
    icon = "__base__/graphics/icons/radar.png",
    icon_size = 64,
    subgroup = "defensive-structure",  -- Same as radar
    order = "d[radar]-z[mission-control-tower]",  -- After radar in build menu
    place_result = "mission-control-tower",
    stack_size = 1  -- As per spec
  }
})
