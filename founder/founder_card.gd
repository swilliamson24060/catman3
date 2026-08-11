extends PanelContainer
class_name FounderCard
## One selectable Founder Cat card. Entirely data-driven -- reads whatever
## DataRegistry hands it from cats.json, so adding a 4th founder later is
## just a new JSON entry, no new card logic.

signal selected(founder_id: String)

const TABBY_TEXTURE_PATH := "res://founder/textures/tabby_fur.png"
const PORTRAITS_DIR := "res://founder/portraits/"

@onready var swatch: TextureRect = $Margin/VBox/Swatch
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var modifiers_label: Label = $Margin/VBox/ModifiersLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var founder_id: String = ""

func setup(founder_data: Dictionary) -> void:
	founder_id = founder_data.get("id", "")
	name_label.text = founder_data.get("display_name", founder_id)
	desc_label.text = founder_data.get("description", "")
	modifiers_label.text = _format_modifiers(founder_data.get("modifiers", []))
	_apply_portrait(founder_data.get("coat", {}))

## Prefers a real rendered portrait (res://founder/portraits/<id>.png, made
## by tools/generate_founder_portraits.gd) when one exists. Falls back to
## the flat color/tabby swatch otherwise -- e.g. for a modder's new founder
## before they've generated art for it -- so the card never ends up blank.
##
## Tries ResourceLoader/load() first: it reads the already-imported .ctex,
## which is what actually ships in an exported build. The raw Image.load()
## byte-read only works in the editor (an exported PCK doesn't contain the
## original PNG, just its imported form) and exists solely so a portrait a
## modder just dropped in -- with no .import metadata yet -- shows up
## without forcing an editor re-scan first.
func _apply_portrait(coat: Dictionary) -> void:
	if founder_id != "":
		var portrait_path := "%s%s.png" % [PORTRAITS_DIR, founder_id]
		if ResourceLoader.exists(portrait_path, "Texture2D"):
			swatch.texture = load(portrait_path)
			swatch.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			return
		elif OS.has_feature("editor"):
			var img := Image.new()
			if img.load(portrait_path) == OK:
				swatch.texture = ImageTexture.create_from_image(img)
				swatch.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				return
	_apply_swatch(coat)

func _apply_swatch(coat: Dictionary) -> void:
	var pattern: String = coat.get("pattern", "solid")
	if pattern == "tabby" and ResourceLoader.exists(TABBY_TEXTURE_PATH):
		swatch.texture = load(TABBY_TEXTURE_PATH)
		return
	var color := Color(coat.get("body_color", "#CCCCCC"))
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(color)
	swatch.texture = ImageTexture.create_from_image(img)

func _ready() -> void:
	select_button.pressed.connect(func(): selected.emit(founder_id))

func _format_modifiers(modifiers: Array) -> String:
	var lines: Array[String] = []
	var reboot_mode := bool(ProjectSettings.get_setting("feature/reboot_mode", true))
	for mod in modifiers:
		# Most of these founders' modifiers predate the reboot and target
		# systems that no longer exist in it (mice recruitment, construction
		# speed) -- showing them to a reboot player describes a game they
		# aren't playing. Only modifiers explicitly marked reboot_relevant
		# (currently just the resident-interest bonus) are shown outside
		# legacy mode; the legacy founder-select screen still shows
		# everything, unfiltered, since those systems are real there.
		if reboot_mode and not bool(mod.get("reboot_relevant", false)):
			continue

		var target: String = mod.get("target", "")
		if target == "resident_interest":
			lines.append(_format_interest_modifier(mod))
			continue

		var stat: String = mod.get("stat", "")
		var value: float = mod.get("value", 0.0)
		var modifier_type: String = mod.get("modifier_type", "multiplier")
		var display_value: String

		if modifier_type == "multiplier":
			var percent := (value - 1.0) * 100.0
			display_value = "%s%.0f%%" % ["+" if percent >= 0 else "", percent]
		else:
			display_value = "%s%s" % ["+" if value >= 0 else "", str(value)]

		var readable_target := target.replace("global_", "").replace("_", " ")
		var readable_stat := stat.replace("_", " ")
		lines.append("%s %s (%s)" % [display_value, readable_stat, readable_target])

	return "\n".join(lines)

## "specialty:gardening" -> "Residents lean toward gardening" -- reads as a
## flavor/personality nudge rather than a raw stat line, matching how small
## this bonus actually is relative to a resident's own specialty/aspiration.
func _format_interest_modifier(mod: Dictionary) -> String:
	var stat: String = mod.get("stat", "")
	var specialty := stat.trim_prefix("specialty:")
	return "Residents lean toward %s" % specialty
