-- Mission Control Tower Item Prototype

data:extend({
  {
    type = "item",
    name = "mission-control-tower",
    icon = "__mission-control__/graphics/entities/tower_icon.png",
    icon_size = 64,
    icon_mipmaps = 4,
    subgroup = "defensive-structure",  -- Same as radar
    order = "d[radar]-z[mission-control-tower]",  -- After radar in build menu
    place_result = "mission-control-tower",
    stack_size = 1  -- As per spec
  }
})
