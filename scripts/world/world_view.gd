extends RefCounted
## Pixelated 3D: the world renders into a 640x360 SubViewport shown full screen with
## nearest filtering, while the UI above it renders at full 1280x720 resolution.

static func create(parent: Node) -> SubViewport:
	var c := SubViewportContainer.new()
	c.name = "WorldView"
	c.stretch = true
	c.stretch_shrink = 2
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var vp := SubViewport.new()
	vp.name = "World"
	vp.audio_listener_enable_3d = true
	vp.physics_object_picking = false
	c.add_child(vp)
	return vp
