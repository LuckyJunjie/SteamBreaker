extends Control
# === ShopUI.gd ===
# 商店界面控制器
# 职责：显示商品列表、购买道具、处理交易（支持金币/帝国债券）

signal item_purchased(item_id: String, quantity: int)
signal shop_closed()

const SHOP_NAME = "杂货商店"
const CURRENCY_SYMBOL = "金克朗"
const EMPIRE_CURRENCY_SYMBOL = "帝国债券"

# 商品目录（后续可从资源配置加载）
var _shop_items: Array = [
    {"id": "repair_kit_small",  "name": "木板修复包",     "price": 100, "desc": "恢复200耐久",    "icon": "🔧"},
    {"id": "boiler_cleaner",    "name": "锅炉清洁剂",    "price": 80,  "desc": "降低30过热值",   "icon": "🧴"},
    {"id": "smoke_bomb",        "name": "烟雾弹",        "price": 150, "desc": "紧急回避+50%",  "icon": "💨"},
    {"id": "sonar_buoy",        "name": "声呐浮标",      "price": 200, "desc": "显示周围敌舰",  "icon": "📡"},
    {"id": "rum_bottle",        "name": "陈年朗姆",      "price": 50,  "desc": "贝索船长喜好",   "icon": "🍾"},
    {"id": "armor_plating",     "name": "铁皮装甲",      "price": 300, "desc": "防御+3回合",     "icon": "🛡️"},
    {"id": "ap_shell",          "name": "穿甲弹",        "price": 250, "desc": "无视30%护甲",   "icon": "💥"},
    {"id": "fire_bomb",         "name": "燃烧弹",        "price": 180, "desc": "持续火焰伤害",   "icon": "🔥"}
]

# 帝国商店商品（仅帝国债券购买）
var _empire_shop_items: Array = [
    {"id": "bp_thunder_cannon",  "name": "雷火炮图纸",     "price": 200, "desc": "风暴岭特殊武器",    "icon": "⚡"},
    {"id": "bp_deep_one_armor",  "name": "深渊甲图纸",     "price": 300, "desc": "深渊海沟特殊护甲",  "icon": "🛡️"},
    {"id": "bp_ironclad_hull",   "name": "铁甲舰船体图纸", "price": 250, "desc": "帝国巡逻舰技术",    "icon": "🚢"},
    {"id": "item_empire_compass", "name": "帝国罗盘",       "price": 150, "desc": "永久显示赏金位置",  "icon": "🧭"},
    {"id": "item_royal_medal",   "name": "皇室勋章",        "price": 100, "desc": "所有商人9折",      "icon": "🎖️"}
]

var _player_gold: int = 0
var _player_bonds: int = 0
var _inventory: Dictionary = {}

# UI节点
var _title_lbl: Label = null
var _gold_lbl: Label = null
var _bonds_lbl: Label = null
var _tab_container: TabContainer = null
var _items_list: VBoxContainer = null
var _empire_items_list: VBoxContainer = null
var _close_btn: Button = null


func _ready() -> void:
    print("[ShopUI] Ready")
    _find_nodes()
    _load_player_data()
    _populate_items()


func _find_nodes() -> void:
    _title_lbl = get_node_or_null(["TitleLabel", "ShopTitle", "VBox/Title"])
    _gold_lbl = get_node_or_null(["GoldLabel", "PlayerGold"])
    _bonds_lbl = get_node_or_null(["BondsLabel", "EmpireBondsLabel"])
    _tab_container = get_node_or_null(["ShopTabs", "TabContainer"])
    _items_list = get_node_or_null(["ItemsList", "ItemsContainer", "ScrollContainer/ListVBox"])
    _empire_items_list = get_node_or_null(["EmpireItemsList", "EmpireItemsContainer"])
    _close_btn = get_node_or_null(["CloseBtn", "CloseButton"])
    
    if _close_btn:
        _close_btn.pressed.connect(_on_close_pressed)


func _load_player_data() -> void:
    # 使用 GameState autoload 获取玩家金币和帝国债券
    _player_gold = GameState.gold if GameState else 5000
    _player_bonds = GameState.empire_bonds if GameState else 0


func _populate_items() -> void:
    # 普通商店
    if not _items_list:
        print("[ShopUI] Warning: ItemsList node not found, creating dynamically")
        _create_shop_layout()
        return
    
    # 清除旧列表
    foreach_child(_items_list, func(c): c.queue_free())
    
    # 标题行
    var header = HBoxContainer.new()
    var name_h = Label.new(); name_h.text = "商品"; name_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var price_h = Label.new(); price_h.text = "价格"; price_h.custom_minimum_size.x = 100
    var action_h = Label.new(); action_h.text = "操作"; action_h.custom_minimum_size.x = 80
    header.add_child(name_h); header.add_child(price_h); header.add_child(action_h)
    _items_list.add_child(header)
    
    # 商品行
    for item in _shop_items:
        _add_item_row(item, false)
    
    # 帝国商店
    if _empire_items_list:
        foreach_child(_empire_items_list, func(c): c.queue_free())
        var empire_header = HBoxContainer.new()
        var ename_h = Label.new(); ename_h.text = "商品"; ename_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var eprice_h = Label.new(); eprice_h.text = "债券"; eprice_h.custom_minimum_size.x = 100
        var eaction_h = Label.new(); eaction_h.text = "操作"; eaction_h.custom_minimum_size.x = 80
        empire_header.add_child(ename_h); empire_header.add_child(eprice_h); empire_header.add_child(eaction_h)
        _empire_items_list.add_child(empire_header)
        
        for item in _empire_shop_items:
            _add_empire_item_row(item)
    
    # 更新货币显示
    if _gold_lbl:
        _gold_lbl.text = "持有金币: %d %s" % [_player_gold, CURRENCY_SYMBOL]
    if _bonds_lbl:
        _bonds_lbl.text = "帝国债券: %d %s" % [_player_bonds, EMPIRE_CURRENCY_SYMBOL]


func _add_item_row(item: Dictionary) -> void:
    var row = HBoxContainer.new()
    row.custom_minimum_size.y = 40
    
    var icon_lbl = Label.new()
    icon_lbl.text = item["icon"]
    icon_lbl.custom_minimum_size.x = 40
    row.add_child(icon_lbl)
    
    var name_lbl = Label.new()
    name_lbl.text = item["name"]
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = item["desc"]
    desc_lbl.modulate = Color(0.6, 0.6, 0.6)
    desc_lbl.custom_minimum_size.x = 150
    row.add_child(desc_lbl)
    
    var price_lbl = Label.new()
    price_lbl.text = "%d %s" % [item["price"], CURRENCY_SYMBOL]
    price_lbl.modulate = Color(1.0, 0.85, 0.3)
    price_lbl.custom_minimum_size.x = 100
    row.add_child(price_lbl)
    
    var buy_btn = Button.new()
    buy_btn.text = "购买"
    buy_btn.custom_minimum_size.x = 80
    if _player_gold < item["price"]:
        buy_btn.disabled = true
        buy_btn.modulate = Color(0.5, 0.5, 0.5)
    else:
        buy_btn.pressed.connect(_on_buy_pressed.bind(item))
    row.add_child(buy_btn)
    
    _items_list.add_child(row)


func _add_empire_item_row(item: Dictionary) -> void:
    var row = HBoxContainer.new()
    row.custom_minimum_size.y = 40
    
    var icon_lbl = Label.new()
    icon_lbl.text = item["icon"]
    icon_lbl.custom_minimum_size.x = 40
    row.add_child(icon_lbl)
    
    var name_lbl = Label.new()
    name_lbl.text = item["name"]
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = item["desc"]
    desc_lbl.modulate = Color(0.6, 0.6, 0.6)
    desc_lbl.custom_minimum_size.x = 150
    row.add_child(desc_lbl)
    
    var price_lbl = Label.new()
    price_lbl.text = "%d %s" % [item["price"], EMPIRE_CURRENCY_SYMBOL]
    price_lbl.modulate = Color(0.5, 0.8, 1.0)
    price_lbl.custom_minimum_size.x = 100
    row.add_child(price_lbl)
    
    var buy_btn = Button.new()
    buy_btn.text = "购买"
    buy_btn.custom_minimum_size.x = 80
    if _player_bonds < item["price"]:
        buy_btn.disabled = true
        buy_btn.modulate = Color(0.5, 0.5, 0.5)
    else:
        buy_btn.pressed.connect(_on_empire_buy_pressed.bind(item))
    row.add_child(buy_btn)
    
    if _empire_items_list:
        _empire_items_list.add_child(row)


func _create_shop_layout() -> void:
    # 如果场景中没有预设布局，动态创建
    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 10)
    add_child(vbox)
    _items_list = vbox
    
    _populate_items()


func _on_buy_pressed(item: Dictionary) -> void:
    if _player_gold < item["price"]:
        print("[ShopUI] Not enough gold for: ", item["name"])
        return
    
    _player_gold -= item["price"]
    print("[ShopUI] Purchased: ", item["name"], " for ", item["price"], " gold")
    
    if GameState:
        GameState.spend_gold(item["price"])
    
    item_purchased.emit(item["id"], 1)
    
    if _gold_lbl:
        _gold_lbl.text = "持有金币: %d %s" % [_player_gold, CURRENCY_SYMBOL]
    
    _populate_items()


func _on_empire_buy_pressed(item: Dictionary) -> void:
    if _player_bonds < item["price"]:
        print("[ShopUI] Not enough empire bonds for: ", item["name"])
        return
    
    _player_bonds -= item["price"]
    print("[ShopUI] Purchased (empire): ", item["name"], " for ", item["price"], " bonds")
    
    if GameState:
        GameState.spend_bonds(item["price"])
    
    item_purchased.emit(item["id"], 1)
    
    if _bonds_lbl:
        _bonds_lbl.text = "帝国债券: %d %s" % [_player_bonds, EMPIRE_CURRENCY_SYMBOL]
    
    _populate_items()


func _on_close_pressed() -> void:
    print("[ShopUI] Closed")
    shop_closed.emit()
    get_tree().quit()


# 辅助函数
func foreach_child(node: Node, fn: Callable) -> void:
    for child in node.get_children():
        fn.call(child)
