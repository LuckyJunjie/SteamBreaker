extends Resource
class_name ShipPart

@export var part_id: String = ""
@export var part_name: String = ""
@export var part_type: String = ""  # hull/boiler/helm/weapon/secondary/special
@export var weight: float = 0.0
@export var price: int = 0
@export var description: String = ""
@export var special_tags: Array[String] = []
