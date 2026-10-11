## A plain Button whose hover tooltip wraps (task 045): client/visual/tooltip_view.gd draws its
## tooltip_text. Used for Brew buttons, the run header's Gear and Brew tags and offer options, whose
## tooltips come from client/help/tooltip_text.gd. Lane: client (Agent B). Display only.
extends Button

const TooltipView := preload("res://client/visual/tooltip_view.gd")


## Godot asks for the tooltip control when the mouse rests on the button.
## for_text: the button's tooltip_text.
func _make_custom_tooltip(for_text: String) -> Object:
	return TooltipView.make(for_text)
