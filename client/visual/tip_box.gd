## A plain HBoxContainer whose hover tooltip wraps (task 045): client/visual/tooltip_view.gd draws its
## tooltip_text. Used for the Bro Meter on the fight screen and the run header's item row. Lane:
## client (Agent B). Display only.
extends HBoxContainer

const TooltipView := preload("res://client/visual/tooltip_view.gd")


## Godot asks for the tooltip control when the mouse rests on the box.
## for_text: the box's tooltip_text.
func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipView.make(for_text)
