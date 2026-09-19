class_name AutoloadRegistry
extends RefCounted

## Resolves project autoload nodes from the SceneTree root. Engine singletons
## and project autoloads are separate registries, so Engine.get_singleton()
## must not be used for these project-owned systems.
static func get_autoload(tree: SceneTree, autoload_name: StringName) -> Node:
	if tree == null or tree.root == null:
		return null
	for child in tree.root.get_children():
		var child_name := str(child.name).trim_prefix("*")
		if StringName(child_name) == autoload_name:
			return child
	return null
