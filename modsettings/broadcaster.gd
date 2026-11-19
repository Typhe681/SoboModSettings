extends RefCounted

signal config_changed(path: String, section: String, value: Variant)
signal action_triggered(path: String, section: String)
